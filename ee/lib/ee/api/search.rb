# frozen_string_literal: true

module EE
  module API
    module Search
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          params :search_params_ee do
            optional :fields, type: Array[String], coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce,
              values: %w[title], desc: 'Array of fields you wish to search'
          end

          override :scope_preload_method
          def scope_preload_method
            super.merge(blobs: :with_api_commit_entity_associations).freeze
          end

          override :search_params
          def search_params
            super.merge(fields: params[:fields])
          end

          override :verify_search_scope!
          def verify_search_scope!(resource:)
            return unless elasticsearch_scope.include?(params[:scope]) && !use_elasticsearch?(resource)

            render_api_error!({ error: 'Scope not supported without Elasticsearch!' }, 400)
          end

          def use_elasticsearch?(resource)
            ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: resource)
          end

          def elasticsearch_scope
            %w[wiki_blobs blobs commits notes].freeze
          end
        end
      end
    end
  end
end
