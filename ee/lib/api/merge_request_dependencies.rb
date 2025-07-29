# frozen_string_literal: true

module API
  class MergeRequestDependencies < ::API::Base
    include PaginationParams

    feature_category :code_review_workflow

    helpers do
      def find_block(merge_request)
        merge_request.blocks_as_blockee.find(params[:block_id])
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all merge request dependencies' do
        success EE::API::Entities::MergeRequestDependency
        tags %w[merge_requests]
        is_array true
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        use :pagination
      end
      get ":id/merge_requests/:merge_request_iid/blocks" do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        present paginate(merge_request.blocks_as_blockee), with: EE::API::Entities::MergeRequestDependency,
          current_user: current_user
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      get ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        present find_block(merge_request),
          with: EE::API::Entities::MergeRequestDependency, current_user: current_user
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        requires :block_id, type: Integer, desc: 'The ID of the merge request dependency'
      end
      delete ":id/merge_requests/:merge_request_iid/blocks/:block_id", urgency: :low do
        merge_request = find_merge_request_with_access(params[:merge_request_iid], :update_merge_request)
        block = find_block(merge_request)

        authorize! :read_merge_request, block.blocking_merge_request

        destroy_conditionally!(block)
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal IID of the blocked merge request'
        requires :blocking_merge_request_id, type: Integer, desc: 'The internal ID of the blocking merge request'
      end
      post ":id/merge_requests/:merge_request_iid/blocks", urgency: :low do
        merge_request = find_project_merge_request(params[:merge_request_iid])

        result =
          ::MergeRequests::CreateBlockService
          .new(
            merge_request: merge_request,
            user: current_user,
            blocking_merge_request_id: params[:blocking_merge_request_id]
          ).execute

        if result.success?
          present result.payload[:merge_request_block], with: EE::API::Entities::MergeRequestDependency, current_user:
            current_user
        else
          render_api_error!(result.message, result.reason)
        end
      end

      desc 'Get all merge requests are blockees for this merge request' do
        success EE::API::Entities::MergeRequestDependency
        tags %w[merge_requests]
        is_array true
      end

      params do
        requires :merge_request_iid, type: Integer, desc: 'The internal ID of the merge request'
        use :pagination
      end
      get ":id/merge_requests/:merge_request_iid/blockees" do
        merge_request = find_merge_request_with_access(params[:merge_request_iid])

        blockees = merge_request.blocks_as_blocker

        present paginate(blockees), with: EE::API::Entities::MergeRequestDependency, current_user: current_user
      end
    end
  end
end
