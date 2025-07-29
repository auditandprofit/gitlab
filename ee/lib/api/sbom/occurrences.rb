# frozen_string_literal: true

module API
  module Sbom
    class Occurrences < ::API::Base
      feature_category :dependency_management
      urgency :low

      LIMIT = 100

      helpers do
        include Gitlab::Utils::StrongMemoize

        def project
          ::Sbom::Occurrence.find(params[:id]).project
        end
        strong_memoize_attr :project

        def vulnerabilities
          Vulnerability.id_in(
            ::Sbom::OccurrencesVulnerability
              .for_occurrence_ids(params[:id])
              .select(:vulnerability_id).limit(LIMIT).ordered_by_vulnerability).with_findings
        end
        strong_memoize_attr :vulnerabilities
      end

      params do
        requires :id, type: String, desc: 'The ID of the occurrence'
      end
      resource :occurrences do
        before do
          authenticate!
          authorize! :read_security_resource, project
        end

        desc 'Get vulnerabilities' do
          detail 'Returns vulnerabilities related to an occurrence.'
        end
        get 'vulnerabilities' do
          options = { occurrence_id: params[:id], project: project }

          present EE::API::Entities::DependenciesVulnerabilities.represent(vulnerabilities, options)
        end
      end
    end
  end
end
