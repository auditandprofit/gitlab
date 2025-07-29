# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      # This API is intended to be consumed by a running Duo Workflow using
      # the ai_workflows scope token. These are requests coming from Duo Workflow
      # Service and Duo Workflow Executor. We should not add any more requests to
      # this API than needed by those 2 components. Otherwise add to
      # `API::Ai::DuoWorkflows::Workflows`.
      class WorkflowsInternal < ::API::Base
        include PaginationParams
        include APIGuard

        helpers ::API::Helpers::DuoWorkflowHelpers

        allow_access_with_scope :ai_workflows

        feature_category :duo_workflow

        before { authenticate! }

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(human_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def human_user
            identity = ::Gitlab::Auth::Identity.fabricate(current_user)
            return identity.scoped_user if identity&.composite? && identity.linked?

            current_user
          end

          def find_event!(workflow, id)
            workflow.events.find(id)
          end

          def render_response(response)
            if response.success?
              status :ok
              response.payload
            else
              render_api_error!(response.message, response.reason)
            end
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            namespace :workflows do
              namespace '/:id' do
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                end
                get do
                  workflow = find_workflow!(params[:id])
                  push_ai_gateway_headers

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow
                end

                desc 'Updates the workflow status' do
                  success code: 200
                end
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                  requires :status_event, type: String, desc: 'The status event',
                    documentation: { example: 'finish' }
                end
                patch do
                  workflow = find_workflow!(params[:id])
                  forbidden! unless current_user.can?(:update_duo_workflow, workflow)

                  service = ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
                    workflow: workflow,
                    status_event: params[:status_event],
                    current_user: current_user
                  )

                  render_response(service.execute)
                end

                namespace :checkpoints do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    optional :parent_ts, type: String, desc: 'The parent ts'
                    requires :checkpoint, type: Hash, desc: "Checkpoint content"
                    requires :metadata, type: Hash, desc: "Checkpoint metadata"
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    checkpoint_params = declared_params(include_missing: false).except(:id)
                    service = ::Ai::DuoWorkflows::CreateCheckpointService.new(
                      workflow: workflow, params: checkpoint_params)
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:checkpoint], with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                  end

                  get do
                    workflow = find_workflow!(params[:id])
                    checkpoints = workflow.checkpoints.ordered_with_writes
                    present paginate(checkpoints), with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                  end

                  namespace '/:checkpoint_id' do
                    params do
                      requires :checkpoint_id, type: Integer, desc: 'The ID of the checkpoint',
                        documentation: { example: 1 }
                    end
                    get do
                      workflow = find_workflow!(params[:id])
                      checkpoint = workflow.checkpoints.with_checkpoint_writes.find_by_id(params[:checkpoint_id])

                      not_found! unless checkpoint

                      present checkpoint, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                    end
                  end
                end

                namespace :checkpoint_writes_batch do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    requires :checkpoint_writes, type: Array, allow_blank: false, desc: 'List of checkpoint writes' do
                      requires :task, type: String, desc: 'The task id'
                      requires :idx, type: Integer, desc: 'The index of checkpoint write'
                      requires :channel, type: String, desc: 'The channel'
                      requires :write_type, type: String, desc: 'The type of data'
                      requires :data, type: String, desc: 'The checkpoint write data'
                    end
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    result = ::Ai::DuoWorkflows::CreateCheckpointWriteBatchService.new(
                      workflow: workflow,
                      params: declared_params(include_missing: false).except(:id)
                    ).execute

                    bad_request!(result.message) if result.error?

                    status :ok
                  end
                end

                namespace :events do
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_type, type: String, values: ::Ai::DuoWorkflows::Event.event_types.keys,
                      desc: 'The type of event'
                    requires :message, type: String, desc: "Message from the human"
                    optional :correlation_id, type: String, desc: "Correlation ID for tracking events",
                      regexp: ::Ai::DuoWorkflows::Event::UUID_REGEXP
                  end
                  post do
                    workflow = find_workflow!(params[:id])
                    event_params = declared_params(include_missing: false).except(:id)
                    service = ::Ai::DuoWorkflows::CreateEventService.new(
                      workflow: workflow,
                      params: event_params.merge(event_status: :queued)
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  get do
                    workflow = find_workflow!(params[:id])
                    events = workflow.events.queued
                    present paginate(events), with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_id, type: Integer, desc: 'The ID of the event'
                    requires :event_status, type: String, values: %w[queued delivered], desc: 'The status of the event'
                  end
                  put '/:event_id' do
                    workflow = find_workflow!(params[:id])
                    event = find_event!(workflow, params[:event_id])
                    event_params = declared_params(include_missing: false).except(:id, :event_id)
                    service = ::Ai::DuoWorkflows::UpdateEventService.new(
                      event: event,
                      params: event_params
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
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
