# frozen_string_literal: true

module CodeSuggestions
  module Xray
    class StoreDependenciesService
      def initialize(project, language, dependencies)
        @project = project
        @language = language
        @dependencies = dependencies
      end

      def execute
        return ServiceResponse.error(message: 'project cannot be blank') if project.blank?
        return ServiceResponse.error(message: 'language cannot be blank') if language.blank?

        payload = {
          "libs" => dependencies.map { |name| { "name" => name } }
        }

        Projects::XrayReport.upsert(
          { project_id: project.id, payload: payload, lang: language },
          unique_by: [:project_id, :lang]
        )

        ServiceResponse.success
      end

      private

      attr_reader :project, :language, :dependencies
    end
  end
end
