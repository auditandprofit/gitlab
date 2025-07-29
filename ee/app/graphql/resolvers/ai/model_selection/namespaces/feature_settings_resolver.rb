# frozen_string_literal: true

module Resolvers
  module Ai
    module ModelSelection
      module Namespaces
        class FeatureSettingsResolver < BaseResolver
          include Gitlab::Graphql::Authorize::AuthorizeResource

          authorize :admin_group_model_selection

          type ::Types::Ai::ModelSelection::Namespaces::FeatureSettingType.connection_type, null: false

          argument :group_id, ::Types::GlobalIDType[::Group],
            required: true,
            description: 'Group for the model selection.'

          def resolve(group_id: nil)
            group = authorized_find!(id: group_id)

            model_definitions = fetch_model_definitions(group)
            feature_settings = get_feature_settings(group)

            ::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting
              .decorate(feature_settings, model_definitions: model_definitions)
          end

          private

          def get_feature_settings(group)
            ::Ai::ModelSelection::Namespaces::FeatureSettingFinder.new(group: group).execute
          end

          def fetch_model_definitions(group)
            fetched_result = ::Ai::ModelSelection::FetchModelDefinitionsService
                                       .new(current_user, model_selection_scope: group)
                                       .execute

            return fetched_result.payload if fetched_result.success?

            raise_resource_not_available_error!(fetched_result.message)
          end
        end
      end
    end
  end
end
