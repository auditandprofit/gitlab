# frozen_string_literal: true

module Gitlab
  module Duo
    module Administration
      class VerifySelfHostedSetup
        attr_reader :ai_gateway_url, :diagnostics

        def initialize(username)
          @user = User.find_by_username!(username || 'root')
          @ai_gateway_url = ::Gitlab::AiGateway.self_hosted_url
          @diagnostics = {}
        end

        def execute
          puts <<~MSG
            ═══════════════════════════════════════════════════════════════
            GitLab Duo Self-Hosted Setup Verification
            ═══════════════════════════════════════════════════════════════
            This task will help you debug issues with your self-hosted Duo installation.
            For additional logs, enable 'expanded_ai_logging' Feature flag

          MSG

          collect_system_info
          verify_ai_gateway_url!
          verify_license_access!
          verify_aigateway_access!
          verify_model_endpoints!
          verify_feature_settings!
          test_request_flow!

          puts "\n#{'═' * 63}"
          puts "DIAGNOSTIC SUMMARY (sanitize before sharing with support)"
          puts "═" * 63
          output_diagnostics
        end

        private

        def collect_system_info
          puts "Collecting system information..."

          @diagnostics[:system] = {
            gitlab_version: Gitlab::VERSION,
            gitlab_revision: Gitlab.revision,
            rails_env: Rails.env,
            timestamp: Time.current.iso8601,
            user: @user.username,
            user_id: @user.id,
            instance_url: Gitlab.config.gitlab.url
          }

          puts ">> System info collected ✔"
          puts ""
        end

        def verify_feature_settings!
          puts "Checking feature settings and model assignments..."

          feature_settings = ::Ai::FeatureSetting.all
          total_features = 0
          feature_data = []
          # rubocop:disable CodeReuse/ActiveRecord -- Need to preload associations for performance
          feature_settings.includes(:self_hosted_model).find_each do |setting|
            model = setting.self_hosted_model
            next unless model # Skip if no self-hosted model is associated

            feature_info = {
              model_id: model.id,
              model_name: model.name,
              model_type: model.model,
              feature_type: setting.feature,
              provider: setting.provider,
              enabled: true
            }
            feature_data << feature_info
            total_features += 1
          end
          # rubocop:enable CodeReuse/ActiveRecord

          # rubocop:disable Rails/Pluck -- Working with array of hashes, not ActiveRecord
          models_with_features_count = feature_data.map { |f| f[:model_id] }.uniq.count
          # rubocop:enable Rails/Pluck

          if total_features == 0
            @diagnostics[:feature_settings] = {
              status: 'WARNING',
              total_features: 0,
              features: [],
              models_with_features: 0,
              warning: 'No feature settings configured for any models'
            }
            puts "   No feature settings configured ⚠"
            puts "   Models may not be available for any GitLab Duo features"
          else
            @diagnostics[:feature_settings] = {
              status: 'OK',
              total_features: total_features,
              features: feature_data,
              models_with_features: models_with_features_count
            }
            puts "   #{total_features} feature settings configured across #{models_with_features_count} models ✔"

            # Group features by model for readable output
            feature_data.group_by { |f| f[:model_name] }.each do |model_name, features|
              # rubocop:disable Rails/Pluck -- Working with array of hashes, not ActiveRecord
              feature_types = features.map { |f| f[:feature_type] }.join(', ')
              # rubocop:enable Rails/Pluck
              puts "     #{model_name}: #{features.count} feature(s) assigned (#{feature_types})"
            end
          end

          puts ""
        end

        def verify_ai_gateway_url!
          puts "Verifying AI Gateway URL configuration..."

          if ai_gateway_url.blank?
            @diagnostics[:ai_gateway_url] = {
              status: 'ERROR',
              url: nil,
              error: 'AI Gateway URL not configured'
            }
            raise "Set 'Ai::Setting.instance.ai_gateway_url' to point to your AI Gateway instance"
          end

          begin
            uri = URI.parse(ai_gateway_url)
            raise URI::InvalidURIError, "URL must be HTTP or HTTPS" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          rescue URI::InvalidURIError => e
            @diagnostics[:ai_gateway_url] = {
              status: 'ERROR',
              url: ai_gateway_url,
              error: "Invalid URL format: #{e.message}"
            }
            raise "Invalid AI Gateway URL format: #{e.message}"
          end

          @diagnostics[:ai_gateway_url] = {
            status: 'OK',
            url: ai_gateway_url,
            scheme: uri.scheme,
            host: uri.host,
            port: uri.port
          }

          puts ">> AI Gateway URL configured: #{ai_gateway_url} ✔"
          puts ""
        end

        def verify_license_access!
          print "Verifying license access to code suggestions..."

          license_available = ::License.feature_available?(:code_suggestions)
          user_has_access = Ability.allowed?(@user, :access_code_suggestions)

          @diagnostics[:license] = {
            feature_available: license_available,
            user_has_access: user_has_access,
            license_type: ::License.current&.plan || 'No license',
            license_expires: ::License.current&.expires_at&.iso8601
          }

          if user_has_access
            puts " ✔"
            return true
          end

          puts " ✗"
          puts "User #{@user.username} has no access to code suggestions, debugging cause..."

          if license_available
            @diagnostics[:license][:error] = "License valid but user lacks access"
            raise <<~MSG
              License is correct, but user does not have access to code suggestions.
              Please check user permissions and submit an issue to GitLab if needed.
            MSG
          end

          @diagnostics[:license][:error] = "License does not provide code suggestions feature"
          raise "License does not provide access to code suggestions, verify your license"
        end

        def verify_aigateway_access!
          puts "Checking AI Gateway accessibility..."

          healthz_url = "#{ai_gateway_url}/monitoring/healthz"
          start_time = Time.current

          begin
            response = Gitlab::HTTP.get(healthz_url,
              headers: { 'accept' => 'application/json' },
              allow_local_requests: true,
              timeout: 10)

            response_time = ((Time.current - start_time) * 1000).round(2)

            @diagnostics[:ai_gateway_health] = {
              status: response.code == 200 ? 'OK' : 'ERROR',
              url: healthz_url,
              http_code: response.code,
              response_time_ms: response_time,
              response_body: response.body.presence,
              response_headers: sanitize_headers(response.headers)
            }

            if response.code == 200
              puts ">> AI Gateway server is accessible ✔"
              puts "   Response time: #{response_time}ms"

              begin
                health_data = ::Gitlab::Json.parse(response.body)
                @diagnostics[:ai_gateway_health][:health_data] = health_data
                puts "   Health status: #{health_data['status'] || 'Unknown'}"
              rescue JSON::ParserError
                puts "   Health response: #{response.body.truncate(100)}"
              end

              return
            else
              puts ">> AI Gateway returned HTTP #{response.code} ✗"
            end

          rescue *Gitlab::HTTP::HTTP_ERRORS => e
            @diagnostics[:ai_gateway_health] = {
              status: 'ERROR',
              url: healthz_url,
              error: e.class.name,
              error_message: e.message,
              response_time_ms: ((Time.current - start_time) * 1000).round(2)
            }
            puts "   Connection error: #{e.class.name} - #{e.message}"
          end

          raise <<~MSG
            Cannot access AI Gateway. Possible causes:
            - AI Gateway is not running
            - 'Ai::Setting.instance.ai_gateway_url' has an incorrect value
            - Network configuration doesn't allow communication between GitLab and AI Gateway
            - Firewall blocking the connection
            - SSL/TLS certificate issues (if using HTTPS)

          MSG
        end

        def verify_model_endpoints!
          puts "Checking self-hosted model configuration..."
          # rubocop:disable CodeReuse/ActiveRecord -- Need to preload associations for performance

          models = ::Ai::SelfHostedModel.includes(:feature_settings)
          # rubocop:enable CodeReuse/ActiveRecord

          if models.empty?
            @diagnostics[:self_hosted_models] = {
              status: 'WARNING',
              count: 0,
              models: [],
              error: 'No self-hosted models configured'
            }
            puts "   No self-hosted models configured ⚠"
            puts ""
            return
          end

          model_data = []
          models.each do |model|
            model_info = {
              id: model.id,
              name: model.name,
              model_type: model.model,
              endpoint: model.endpoint,
              identifier: model.identifier.presence || 'default',
              release_state: model.release_state,
              ga: model.ga?,
              provider: model.provider,
              has_api_token: model.api_token.present?
            }
            model_data << model_info

            status_icon = if model.ga?
                            '✔'
                          else
                            (model.release_state == 'BETA' ? '⚠' : '⚡')
                          end

            puts "   #{model.name} (#{model.model}): #{model.endpoint} #{status_icon}"
            puts "     Release state: #{model.release_state} | Provider: #{model.provider}"
            puts "     API token: #{model.api_token.present? ? 'Configured' : 'Missing'}"
          end

          @diagnostics[:self_hosted_models] = {
            status: 'OK',
            count: models.count,
            models: model_data,
            ga_models_count: models.ga_models.count
          }

          puts ""
        end

        def test_request_flow!
          puts "Testing request flow to configured models..."
          # rubocop:disable CodeReuse/ActiveRecord -- Need to preload associations for performance

          models = ::Ai::SelfHostedModel.includes(:feature_settings)
          # rubocop:enable CodeReuse/ActiveRecord

          if models.empty?
            @diagnostics[:request_flow] = {
              status: 'SKIPPED',
              reason: 'No models configured to test'
            }
            puts "   Skipping request flow test - no models configured"
            puts ""
            return
          end

          model_tests = []

          models.each do |model|
            puts "   Testing model: #{model.name} (#{model.model})..."

            test_result = test_model_endpoint(model)
            model_tests << test_result

            case test_result[:status]
            when 'OK'
              puts "     ✔ Model endpoint accessible"
            when 'WARNING'
              puts "     ⚠ Model endpoint returned non-200 status"
            when 'ERROR'
              puts "     ✗ Model endpoint failed: #{test_result[:error]}"
            end
          end

          @diagnostics[:request_flow] = {
            status: model_tests.any? { |t| t[:status] == 'OK' } ? 'OK' : 'ERROR',
            models_tested: model_tests.count,
            model_tests: model_tests
          }

          puts ""
        end

        def test_model_endpoint(model)
          start_time = Time.current

          begin
            headers = {
              'accept' => 'application/json',
              'content-type' => 'application/json',
              'user-agent' => "GitLab-Duo/#{Gitlab::VERSION}"
            }

            headers['authorization'] = "Bearer #{model.api_token}" if model.api_token.present?

            test_url = "#{model.endpoint.chomp('/')}/v1/models"

            response = Gitlab::HTTP.get(test_url,
              headers: headers,
              allow_local_requests: true,
              timeout: 10)

            response_time = ((Time.current - start_time) * 1000).round(2)

            {
              model_id: model.id,
              model_name: model.name,
              status: response.code < 400 ? 'OK' : 'WARNING',
              endpoint: test_url,
              http_code: response.code,
              response_time_ms: response_time,
              response_size: response.body.bytesize,
              has_auth: model.api_token.present?
            }

          rescue *Gitlab::HTTP::HTTP_ERRORS => e
            {
              model_id: model.id,
              model_name: model.name,
              status: 'ERROR',
              endpoint: "#{model.endpoint.chomp('/')}/v1/models",
              error: e.class.name,
              error_message: e.message,
              response_time_ms: ((Time.current - start_time) * 1000).round(2),
              has_auth: model.api_token.present?
            }
          end
        end

        def output_diagnostics
          puts ::Gitlab::Json.pretty_generate(@diagnostics)
          puts ""
          puts "NOTE: Review the above output and remove any sensitive information"
          puts "before sharing with GitLab support."
        end

        def sanitize_headers(headers)
          return {} unless headers.is_a?(Hash)

          sensitive_headers = %w[authorization x-api-key x-auth-token cookie set-cookie]

          headers.reject { |k, _| k.respond_to?(:downcase) && sensitive_headers.include?(k.downcase) }
                 .transform_values { |v| v.is_a?(String) ? v.truncate(100) : v }
        end
      end
    end
  end
end
