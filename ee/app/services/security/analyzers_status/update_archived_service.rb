# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateArchivedService
      def self.execute(project)
        new(project).execute
      end

      def initialize(project)
        @project = project
      end

      def execute
        return unless project&.analyzer_statuses&.exists?

        update_analyzer_statuses
      end

      private

      attr_reader :project

      def update_analyzer_statuses
        project.analyzer_statuses.update!(archived: project.archived)
      end
    end
  end
end
