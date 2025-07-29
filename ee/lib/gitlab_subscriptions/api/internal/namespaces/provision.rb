# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class Namespaces
        class Provision < ::API::Base
          feature_category :plan_provisioning
          urgency :low

          namespace :internal do
            namespace :gitlab_subscriptions do
              resource :namespaces, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
                before do
                  @namespace = find_namespace(params[:id])

                  not_found!('Namespace') unless @namespace
                  bad_request!('Must be root namespace') unless @namespace.root?
                end

                helpers do
                  params :base_product do
                    optional :plan_code, type: String, desc: 'The plan code for subscription'
                    optional :start_date, type: Date, desc: 'Start date of subscription'
                    optional :end_date, type: Date, desc: 'End date of subscription'
                    optional :seats, type: Integer, desc: 'Number of seats'
                    optional :max_seats_used, type: Integer, desc: 'Max seats used'
                    optional :trial, type: Boolean, desc: 'Whether subscription is a trial'
                    optional :trial_starts_on, type: Date, desc: 'Trial start date'
                    optional :trial_ends_on, type: Date, desc: 'Trial end date'
                    optional :auto_renew, type: Boolean, desc: 'Whether subscription auto renews'
                  end

                  params :compute_minutes do
                    optional :shared_runners_minutes_limit, type: Integer, desc: 'Base minutes included in plan'
                    optional :extra_shared_runners_minutes_limit, type: Integer, desc: 'Additional purchased minutes'
                  end

                  params :storage do
                    optional :additional_purchased_storage_size, type: Integer, desc: 'Additional storage size'
                    optional :additional_purchased_storage_ends_on, type: Date, desc: 'Additional storage end date'
                  end

                  params :add_on do
                    requires :started_on, type: Date, desc: 'Add-on purchase start date'
                    requires :expires_on, type: Date, desc: 'Add-on purchase end date'
                    optional :quantity, type: Integer,
                      values: { value: ->(v) { v >= 0 }, message: 'Must be a non-negative integer if provided' }
                    optional :purchase_xid, type: String, desc: 'Add-on purchase identifier'
                    optional :trial, type: Boolean, default: false, desc: 'Whether Add-on purchase is a trial'
                    optional :new_subscription, type: Boolean, desc: 'Whether add-on purchase is for a new subscription'
                  end
                end

                desc 'Provision a namespace' do
                  detail 'Complete provisioning of a namespace with base product, add-on purchases,' \
                    'compute minutes, and storage'
                  success Entities::Internal::Namespace
                  failure [
                    { code: 400, message: 'Bad Request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 404, message: 'Not Found' },
                    { code: 422, message: 'Unprocessable Entity' }
                  ]
                end
                params do
                  requires :provision, type: Hash do
                    optional :base_product, type: Hash do
                      use :base_product
                    end
                    optional :compute_minutes, type: Hash do
                      use :compute_minutes
                    end
                    optional :storage, type: Hash do
                      use :storage
                    end
                    optional :add_on_purchases, type: Hash do
                      optional :duo_core, type: Array do
                        use :add_on
                      end
                      optional :duo_pro, type: Array do
                        use :add_on
                      end
                      optional :duo_enterprise, type: Array do
                        use :add_on
                      end
                      optional :product_analytics, type: Array do
                        use :add_on
                      end
                    end
                  end
                end

                post ':id/provision' do
                  result = ::GitlabSubscriptions::Provision::SyncNamespaceService.new(
                    namespace: @namespace,
                    params: declared_params(include_missing: false)[:provision]
                  ).execute

                  if result.success?
                    status :ok
                  else
                    render_api_error!(result.message, :unprocessable_entity)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
