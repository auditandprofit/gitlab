# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    module Clients
      module Rest
        extend ActiveSupport::Concern

        class_methods do
          SubscriptionPortalRESTException = Class.new(RuntimeError)

          def generate_trial(params)
            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post("trials", admin_headers, trial_user_params)
          end

          def generate_addon_trial(params)
            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post("trials/create_addon", admin_headers, trial_user_params)
          end

          def generate_lead(params)
            http_post("trials/create_hand_raise_lead", admin_headers, params)
          end

          def generate_iterable(params)
            http_post("trials/create_iterable", admin_headers, params)
          end

          def opt_in_lead(params)
            http_post("api/marketo_leads/opt_in", admin_headers, params)
          end

          def payment_form_params(payment_type, user_id)
            http_get("payment_forms/#{payment_type}", admin_headers, { user_id: user_id }.compact)
          end

          def payment_method(id)
            http_get("api/payment_methods/#{id}", admin_headers)
          end

          def validate_payment_method(id, params)
            http_post("api/payment_methods/#{id}/validate", admin_headers, params)
          end

          def create_seat_link(seat_link)
            raise TypeError unless seat_link.is_a?(Gitlab::SeatLinkData)

            http_post("api/v1/seat_links", json_headers, seat_link)
          end

          def namespace_eligible_trials(params)
            http_get('api/v1/gitlab/namespaces/trials/eligibility', admin_headers, params)
          end

          private

          def error_message
            _('Our team has been notified. Please try again.')
          end

          def track_exception(message)
            Gitlab::ErrorTracking.track_exception(SubscriptionPortalRESTException.new(message))
          end

          def base_url
            ::Gitlab::Routing.url_helpers.subscription_portal_url
          end

          def http_get(path, headers, query = {})
            process_http_call { Gitlab::HTTP.get("#{base_url}/#{path}", query: query, headers: headers) }
          end

          def http_post(path, headers, params = {})
            process_http_call do
              Gitlab::HTTP.post("#{base_url}/#{path}", body: params.to_json, headers: headers)
            end
          end

          def process_http_call
            response = yield
            parse_response(response)
          rescue *Gitlab::HTTP::HTTP_ERRORS => e
            track_exception(e.message)
            { success: false, data: { errors: error_message } }.with_indifferent_access
          end
        end
      end
    end
  end
end
