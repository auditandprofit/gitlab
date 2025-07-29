# frozen_string_literal: true

class MergeRequestBlock < ApplicationRecord
  belongs_to :blocking_merge_request, class_name: 'MergeRequest'
  belongs_to :blocked_merge_request, class_name: 'MergeRequest'

  validates_presence_of :blocking_merge_request
  validates_presence_of :blocked_merge_request
  validates_uniqueness_of :blocked_merge_request, scope: :blocking_merge_request

  validate :check_block_constraints

  MAX_BLOCKS_COUNT = 10
  MAX_BLOCKED_BY_COUNT = 10

  scope :with_blocking_mr_ids, ->(ids) do
    where(blocking_merge_request_id: ids).includes(:blocking_merge_request)
  end

  private

  def check_block_constraints
    return unless blocking_merge_request && blocked_merge_request

    errors.add(:base, _('This block is self-referential')) if
      blocking_merge_request == blocked_merge_request

    if blocks_count >= MAX_BLOCKS_COUNT
      error_string = "Merge request blocks the maximum number of merge requests (#{MAX_BLOCKS_COUNT})"
      errors.add(:base, _(error_string))
    end

    return unless blocked_by_count >= MAX_BLOCKED_BY_COUNT

    error_string = "Merge request is blocked by the maximum number of merge requests (#{MAX_BLOCKED_BY_COUNT})"
    errors.add(:base, _(error_string))
  end

  def blocked_by_count
    blocking_merge_request.blocks_as_blockee.count
  end

  def blocks_count
    blocked_merge_request.blocks_as_blocker.count
  end
end
