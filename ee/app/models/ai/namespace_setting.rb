# frozen_string_literal: true

module Ai
  class NamespaceSetting < ApplicationRecord
    self.table_name = "namespace_ai_settings"

    validates :duo_workflow_mcp_enabled, inclusion: { in: [true, false] }

    belongs_to :namespace, inverse_of: :ai_settings
  end
end
