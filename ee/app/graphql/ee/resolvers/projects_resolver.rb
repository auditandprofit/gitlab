# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :include_hidden, GraphQL::Types::Boolean,
          required: false,
          description: 'Include hidden projects.'

        argument :with_code_embeddings_indexed, GraphQL::Types::Boolean,
          required: false,
          experiment: { milestone: '18.2' },
          description: "Include projects with indexed code embeddings. " \
            "Requires `ids` to be sent. Applies only if the feature flag " \
            "`allow_with_code_embeddings_indexed_projects_filter` is enabled."

        before_connection_authorization do |projects, current_user|
          ::Preloaders::UserMaxAccessLevelInProjectsPreloader.new(projects, current_user).execute
          ::Preloaders::UserMemberRolesInProjectsPreloader.new(projects: projects, user: current_user).execute
        end
      end

      private

      override :finder_params
      def finder_params(args)
        super(args)
          .merge(args.slice(:include_hidden, :with_code_embeddings_indexed))
          .merge(filter_expired_saml_session_projects: true)
      end

      override :validate_args!
      def validate_args!(args)
        super(args)

        return unless args[:with_code_embeddings_indexed].present? && args[:ids].nil?

        raise ::Gitlab::Graphql::Errors::ArgumentError, 'with_code_embeddings_indexed should be only used with ids'
      end
    end
  end
end
