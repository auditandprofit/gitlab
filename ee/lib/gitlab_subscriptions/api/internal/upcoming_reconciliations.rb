# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class UpcomingReconciliations < ::API::Base
        before do
          forbidden!('This API is gitlab.com only!') unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

          @namespace = find_namespace(params[:namespace_id])
          not_found!('Namespace') unless @namespace.present?
        end

        feature_category :subscription_management
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource 'namespaces/:namespace_id' do
              params do
                requires :namespace_id, type: Integer, allow_blank: false
              end
              resource :upcoming_reconciliations do
                desc 'Update upcoming reconciliations'
                params do
                  requires :next_reconciliation_date, type: Date
                  requires :display_alert_from, type: Date
                end
                put '/' do
                  attributes = {
                    next_reconciliation_date: params[:next_reconciliation_date],
                    display_alert_from: params[:display_alert_from]
                  }

                  reconciliation = GitlabSubscriptions::UpcomingReconciliation.next(@namespace.id)

                  if reconciliation
                    reconciliation.update!(attributes)
                  else
                    GitlabSubscriptions::UpcomingReconciliation.create!(
                      attributes.merge({ namespace: @namespace, organization: @namespace.organization })
                    )
                  end

                  status 200
                rescue ActiveRecord::RecordInvalid => e
                  render_api_error!({ error: e.record.errors.full_messages.join(', ') }, 500)
                end

                desc 'Destroy upcoming reconciliation record'
                delete '/' do
                  upcoming_reconciliation = ::GitlabSubscriptions::UpcomingReconciliation.next(params[:namespace_id])

                  not_found! if upcoming_reconciliation.blank?

                  upcoming_reconciliation.destroy!

                  no_content!
                end
              end
            end
          end
        end
      end
    end
  end
end
