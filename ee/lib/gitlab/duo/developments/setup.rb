# frozen_string_literal: true

# rubocop:disable Gitlab/DocumentationLinks/HardcodedUrl -- Development purpose
module Gitlab
  module Duo
    module Developments
      def self.seed_data(namespace)
        if Group.find_by_full_path(namespace)
          puts <<~TXT.strip
          ================================================================================
          ## Gitlab Duo test group and project already seeded
          ## If you want to destroy and re-create them, you can re-run the seed task
          ## SEED_GITLAB_DUO=1 FILTER=gitlab_duo bundle exec rake db:seed_fu
          ## See https://docs.gitlab.com/development/ai_features/testing_and_validation/#seed-project-and-group-resources-for-testing-and-evaluation
          ================================================================================
          TXT
        else
          # see ee/db/fixtures/development/95_gitlab_duo.rb
          puts "Seeding GitLab Duo data..."
          ENV['FILTER'] = 'gitlab_duo'
          ENV['SEED_GITLAB_DUO'] = '1'
          Rake::Task['db:seed_fu'].invoke
        end
      end

      class BaseStrategy
        def initialize(namespace, args)
          @namespace = namespace
          @args = args
        end

        private

        def create_add_on_purchases!(group: nil)
          ::GitlabSubscriptions::AddOnPurchase.by_namespace(group).delete_all

          duo_core_add_on = ::GitlabSubscriptions::AddOn.find_or_create_by_name(:duo_core)
          response = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(
            group,
            duo_core_add_on,
            {
              quantity: 100,
              started_on: Time.current,
              expires_on: 1.year.from_now,
              purchase_xid: 'A-S0001'
            }
          ).execute

          raise response.message unless response.success?

          if @args[:add_on] == 'duo_pro'
            create_duo_pro_purchase!(group)
          else
            create_enterprise_purchase!(group)
          end
        end

        def create_duo_pro_purchase!(group)
          add_on = ::GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions)

          response = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(group, add_on, {
            quantity: 100,
            started_on: Time.current,
            expires_on: 1.year.from_now,
            purchase_xid: 'C-12345'
          }).execute

          raise response.message unless response.success?

          response.payload[:add_on_purchase].update!(users: [User.find_by_username('root')])

          puts "Duo Pro add-on added..."
        end

        def create_enterprise_purchase!(group)
          add_on = ::GitlabSubscriptions::AddOn.find_or_create_by_name(:duo_enterprise)

          response = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(group, add_on, {
            quantity: 100,
            started_on: Time.current,
            expires_on: 1.year.from_now,
            purchase_xid: 'C-98766'
          }).execute

          raise response.message unless response.success?

          response.payload[:add_on_purchase].update!(users: [User.find_by_username('root')])
          puts "Duo enterprise add-on added..."
        end
      end

      class SelfManagedStrategy < BaseStrategy
        def execute
          puts <<~TXT.strip
          ================================================================================
          ## Running self-managed mode setup
          ## If you want to run .com mode, set GITLAB_SIMULATE_SAAS=1
          ## and re-run this script
          ## See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance
          ## for more information.
          ================================================================================
          TXT

          require_self_managed!

          Developments.seed_data(@namespace)
          create_add_on_purchases!
        end

        private

        # rubocop:disable Style/GuardClause -- For reading simplicity
        def require_self_managed!
          if ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
            raise <<~MSG
              Make sure 'GITLAB_SIMULATE_SAAS' environment variable is false or not set.
              See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance for more information.
            MSG
          end
        end
        # rubocop:enable Style/GuardClause
      end

      class GitlabComStrategy < BaseStrategy
        def execute
          puts <<~TXT.strip
          ================================================================================
          ## Running GitLab.com mode setup for group '#{@namespace}'
          ## If you want to run self-managed mode, set GITLAB_SIMULATE_SAAS=0
          ## and re-run this script
          ## See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance
          ## for more information.
          ================================================================================
          TXT

          ensure_application_settings!

          Developments.seed_data(@namespace)

          group = Group.find_by_full_path(@namespace)
          ensure_group_subscription!(group)
          ensure_group_settings!(group)
          create_add_on_purchases!(group: group)
        end

        private

        # rubocop:disable CodeReuse/ActiveRecord -- Development purpose
        def ensure_group_subscription!(group)
          puts "Activating an Ultimate license to the group...."

          plan = Plan.find_or_create_by(name: "ultimate", title: "Ultimate")

          GitlabSubscription.find_or_create_by(namespace: group).tap do |subscription|
            subscription.update!(hosted_plan_id: plan.id, seats: 100)
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord

        def ensure_application_settings!
          puts "Enabling application settings...."

          Gitlab::CurrentSettings.current_application_settings.update!(
            check_namespace_plan: true,
            allow_local_requests_from_web_hooks_and_services: true,
            instance_level_ai_beta_features_enabled: true,
            duo_features_enabled: true
          )
        end

        def ensure_group_settings!(group)
          puts "Enabling the group settings...."

          group = Group.find(group.id) # Hard Reload for refreshing the cache
          group.update!(
            experiment_features_enabled: true
          )

          group.namespace_settings.update!(
            duo_features_enabled: true,
            duo_core_features_enabled: true
          )
        end
      end

      class Setup
        attr_reader :args

        def initialize(args)
          @args = args
          @namespace = 'gitlab-duo' # Same with Gitlab::Seeder::GitLabDuo::GROUP_PATH
        end

        def execute
          setup_strategy = if ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
                             GitlabComStrategy.new(@namespace, @args)
                           else
                             SelfManagedStrategy.new(nil, @args)
                           end

          ensure_dev_mode!
          ensure_feature_flags!
          ensure_license!
          setup_strategy.execute

          print_result
        end

        private

        # rubocop:disable Style/GuardClause -- Keep it explicit
        def ensure_dev_mode!
          unless ::Gitlab.dev_or_test_env?
            raise <<~MSG
              Setup can only be performed in development or test environment, however, the current environment is #{ENV['RAILS_ENV']}.
            MSG
          end
        end
        # rubocop:enable Style/GuardClause

        def ensure_feature_flags!
          puts "Enabling feature flags...."

          Gitlab::Duo::Developments::FeatureFlagEnabler.execute
          ::Feature.enable(:enable_hamilton_in_user_preferences)
          ::Feature.enable(:allow_organization_creation)

          # this feature flag is for making staging-ref act like a self-managed instance.
          # when enabled, it makes SaaS mode like Self-Managed mode when it comes to
          # certain Duo things so best to disable
          ::Feature.disable(:allow_self_hosted_features_for_com)
        end

        def ensure_license!
          license = ::License.current
          raise 'No license found' unless license
        end

        def print_result
          puts <<~MSG
            ----------------------------------------
            Setup Complete!
            ----------------------------------------

            Visit "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/#{@namespace.presence}" for testing GitLab Duo features.

            For more development guidelines, see https://docs.gitlab.com/ee/development/ai_features/.
          MSG

          Group.find_by_full_path(@namespace)
        end
      end
    end
  end
end
# rubocop:enable Gitlab/DocumentationLinks/HardcodedUrl
