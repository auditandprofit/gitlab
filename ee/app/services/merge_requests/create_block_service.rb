# frozen_string_literal: true

module MergeRequests
  class CreateBlockService
    include ::Gitlab::Allowable

    def initialize(user:, merge_request:, blocking_merge_request_id:)
      @user = user
      @merge_request = merge_request
      @blocking_merge_request_id = blocking_merge_request_id
    end

    def execute
      unless can?(user, :update_merge_request, merge_request)
        return ::ServiceResponse.error(message: _("Lacking permissions to update the merge request"),
          reason: :forbidden)
      end

      # rubocop: disable CodeReuse/ActiveRecord -- Move to a service/function
      blocking_mr = ::MergeRequest.find_by(id: blocking_merge_request_id)
      # rubocop: enable CodeReuse/ActiveRecord

      if blocking_mr.nil?
        return ::ServiceResponse.error(message: _("Blocking merge request not found"), reason: :not_found)
      end

      unless can?(user, :read_merge_request, blocking_mr)
        return ::ServiceResponse.error(message: _("Lacking permissions to the blocking merge request"),
          reason: :forbidden)
      end

      block = ::MergeRequestBlock.create(
        blocking_merge_request_id: blocking_mr.id,
        blocked_merge_request_id: merge_request.id
      )

      block_exists = block.errors.any? { |error| error.try(:type) == :taken }

      return ::ServiceResponse.error(message: _("Block already exists"), reason: :conflict) if block_exists

      unless block.persisted?
        return ::ServiceResponse.error(message: block.errors.full_messages.join(', '), reason: :bad_request)
      end

      ::ServiceResponse.success(payload: { merge_request_block: block })
    end

    private

    attr_reader :merge_request, :blocking_merge_request_id, :user
  end
end
