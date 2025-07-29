# frozen_string_literal: true

module Ai
  class AgentVersion < ApplicationRecord
    self.table_name = "ai_agent_versions"

    include GlobalID::Identification

    validates :project, :agent, presence: true

    validates :prompt,
      length: { maximum: 5000 },
      presence: true

    validates :model,
      length: { maximum: 255 },
      presence: true

    validate :validate_agent

    has_many :attachments, class_name: 'Ai::AgentVersionAttachment',
      foreign_key: :ai_agent_version_id, inverse_of: :version
    has_many :files, through: :attachments, source: :file

    belongs_to :agent, class_name: 'Ai::Agent'
    belongs_to :project

    scope :order_by_agent_id_id_desc, -> { order('agent_id, id DESC') }
    scope :latest_by_agent, -> { order_by_agent_id_id_desc.select('DISTINCT ON (agent_id) *') }

    private

    def validate_agent
      return unless agent

      errors.add(:agent, 'agent project must be the same') if agent.project_id != project_id
    end
  end
end
