# frozen_string_literal: true

module Clusters
  module Agents
    module AutoFlow
      module WorkItems
        class UpdatedEventWorker # rubocop:disable Scalability/IdempotentWorker -- Rubocop doesn't respect the idempotent! from the included subscriber
          include Gitlab::EventStore::Subscriber

          feature_category :deployment_management
          data_consistency :sticky

          AUTOFLOW_EVENT_TYPE = "com.gitlab.events.issue_updated"

          def handle_event(event)
            # we only ever emit events for projects that this points
            issue_id = event.data[:id]

            work_item = ::WorkItem.find_by_id(issue_id)
            return unless work_item && work_item.project.present?

            issue_iid = work_item.iid
            project = work_item.project

            client = Gitlab::Kas::Client.new
            client.send_autoflow_event(
              project: project,
              type: AUTOFLOW_EVENT_TYPE,
              id: SecureRandom.uuid,
              data: {
                project: {
                  id: project.id
                },
                issue: {
                  id: issue_id,
                  iid: issue_iid
                }
              }
            )
          end
        end
      end
    end
  end
end
