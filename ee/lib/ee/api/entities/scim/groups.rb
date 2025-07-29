# frozen_string_literal: true

module EE
  module API
    module Entities
      module Scim
        # rubocop:disable Gitlab/EeOnlyClass -- All existing instance SCIM code
        # currently lives under ee/ and making it compliant requires a larger
        # refactor to be addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/520129.
        class Groups < Grape::Entity
          expose :schemas
          expose :total_results, as: :totalResults
          expose :items_per_page, as: :itemsPerPage
          expose :start_index, as: :startIndex

          expose :resources, as: :Resources, using: ::EE::API::Entities::Scim::Group

          private

          DEFAULT_SCHEMA = 'urn:ietf:params:scim:api:messages:2.0:ListResponse'

          def schemas
            [DEFAULT_SCHEMA]
          end

          def total_results
            object[:total_results] || resources.count
          end

          def items_per_page
            object[:items_per_page] || Kaminari.config.default_per_page
          end

          def start_index
            object[:start_index].presence || 1
          end

          def resources
            object[:resources] || []
          end
        end
        # rubocop:enable Gitlab/EeOnlyClass
      end
    end
  end
end
