# frozen_string_literal: true

module Clusters
  module Agents
    module AutoFlow
      module MergeRequests
        class UpdatedEventWorker # rubocop:disable Scalability/IdempotentWorker -- Rubocop doesn't respect the idempotent! from the included subscriber
          include Gitlab::EventStore::Subscriber

          feature_category :deployment_management
          data_consistency :sticky

          AUTOFLOW_EVENT_TYPE = "com.gitlab.events.merge_request_updated"

          def handle_event(event)
            merge_request = ::MergeRequest.find_by_id(event.data[:merge_request_id])

            return unless merge_request

            project = merge_request.target_project
            id = merge_request.id
            iid = merge_request.iid

            client = Gitlab::Kas::Client.new
            client.send_autoflow_event(
              project: project,
              type: AUTOFLOW_EVENT_TYPE,
              id: SecureRandom.uuid,
              data: {
                project: {
                  id: project.id
                },
                merge_request: {
                  id: id,
                  iid: iid
                }
              }
            )
          end
        end
      end
    end
  end
end
