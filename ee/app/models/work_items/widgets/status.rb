# frozen_string_literal: true

module WorkItems
  module Widgets
    class Status < Base
      def self.quick_action_commands
        [:status]
      end

      def self.quick_action_params
        [:status]
      end
    end
  end
end
