# frozen_string_literal: true

module EE
  module API
    module Entities
      class DependenciesVulnerabilities < Grape::Entity
        expose :occurrence_id do |_, options|
          options[:occurrence_id]
        end

        expose :id

        expose :name do |vulnerability|
          vulnerability.finding.name
        end

        expose :url do |vulnerability, options|
          vulnerability_url(options[:project], vulnerability.id)
        end

        expose :severity

        private

        def vulnerability_url(project, id)
          ::Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, id)
        end
      end
    end
  end
end
