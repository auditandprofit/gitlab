# frozen_string_literal: true

module Ai
  class TroubleshootJobEvent < ApplicationRecord
    include BaseUsageEvent

    self.table_name = "ai_troubleshoot_job_events"
    self.clickhouse_table_name = "troubleshoot_job_events"

    enum :event, { troubleshoot_job: 1 }

    belongs_to :project
    belongs_to :job, class_name: 'Ci::Build'

    validates :job_id, :project_id, presence: true

    populate_sharding_key :project_id, source: :job

    before_validation :fill_payload

    def self.permitted_attributes
      super + %w[project_id merge_request_id job]
    end

    def to_clickhouse_csv_row
      super.merge({
        user_id: user_id,
        project_id: project_id,
        job_id: job_id,
        pipeline_id: payload['pipeline_id'],
        merge_request_id: payload['merge_request_id']
      })
    end

    private

    def fill_payload
      payload['pipeline_id'] ||= job&.pipeline_id
      payload['merge_request_id'] ||= job&.pipeline&.merge_request_id
    end
  end
end
