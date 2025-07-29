# frozen_string_literal: true

module Ai
  class AgentVersionAttachment < ApplicationRecord
    self.table_name = "ai_agent_version_attachments"

    validates :project, :version, :file, presence: true

    belongs_to :project
    belongs_to :version, class_name: 'Ai::AgentVersion', foreign_key: :ai_agent_version_id, inverse_of: :attachments
    belongs_to :file, class_name: 'Ai::VectorizableFile', foreign_key: :ai_vectorizable_file_id,
      inverse_of: :attachments
  end
end
