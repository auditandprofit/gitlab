# frozen_string_literal: true

module Vulnerabilities
  module Removal
    module Tasks
      class AbstractTaskScopedToFinding
        class << self
          attr_accessor :model
        end

        def initialize(finding_ids)
          @finding_ids = finding_ids
        end

        def execute
          loop do
            deleted_count = self.class.model.by_finding_id(finding_ids).limit(100).delete_all

            break if deleted_count == 0
          end
        end

        private

        attr_reader :finding_ids
      end
    end
  end
end
