# frozen_string_literal: true

module EE
  module Projects
    module Commit
      include ::Ai::Model

      def resource_parent
        project
      end
    end
  end
end
