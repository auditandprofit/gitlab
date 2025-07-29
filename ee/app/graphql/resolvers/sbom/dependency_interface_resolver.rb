# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependencyInterfaceResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include Gitlab::InternalEventsTracking
      include LooksAhead

      SORT_TO_PARAMS_MAP = {
        name_desc: { sort_by: 'name', sort: 'desc' },
        name_asc: { sort_by: 'name', sort: 'asc' },
        packager_desc: { sort_by: 'packager', sort: 'desc' },
        packager_asc: { sort_by: 'packager', sort: 'asc' },
        severity_desc: { sort_by: 'severity', sort: 'desc' },
        severity_asc: { sort_by: 'severity', sort: 'asc' },
        license_asc: { sort_by: 'primary_license_spdx_identifier', sort: 'asc' },
        license_desc: { sort_by: 'primary_license_spdx_identifier', sort: 'desc' }
      }.freeze

      authorize :read_dependency
      authorizes_object!

      type Types::Sbom::DependencyInterface.connection_type, null: true

      argument :sort, Types::Sbom::DependencySortEnum,
        required: false,
        description: 'Sort dependencies by given criteria.'

      argument :package_managers, [Types::Sbom::PackageManagerEnum],
        required: false,
        description: 'Filter dependencies by package managers.'

      argument :component_names, [GraphQL::Types::String],
        required: false,
        description: 'Filter dependencies by component names.'

      argument :component_ids, [Types::GlobalIDType[::Sbom::Component]],
        required: false,
        description: 'Filter dependencies by component IDs.'

      argument :source_types, [Types::Sbom::SourceTypeEnum],
        required: false,
        default_value: ::Sbom::Source::DEFAULT_SOURCES.keys.map(&:to_s) + ['nil_source'],
        description: 'Filter dependencies by source type.'

      argument :component_versions, [GraphQL::Types::String],
        required: false,
        description: 'Filter dependencies by component versions.'

      argument :not_component_versions, [GraphQL::Types::String],
        required: false,
        description: 'Filter dependencies to exclude the specified component versions.',
        experiment: { milestone: '18.1' }

      validates mutually_exclusive: [:component_names, :component_ids]

      alias_method :project_or_namespace, :object

      def resolve_with_lookahead(**args)
        return ::Sbom::Occurrence.none unless project_or_namespace

        args[:component_ids] = resolve_gids(args[:component_ids], ::Sbom::Component) if args[:component_ids]

        list = dependencies(args)

        track_event

        offset_pagination(list)
      end

      def preloads
        {
          name: [:component],
          version: [:component_version],
          component_version: [:component_version],
          packager: [:source],
          location: [:source],
          vulnerabilities: [:vulnerabilities]
        }
      end

      private

      def resolve_gids(gids, gid_class)
        gids.map do |gid|
          Types::GlobalIDType[gid_class].coerce_isolated_input(gid).model_id
        end
      end

      def dependencies(params)
        raise NotImplementedError, "#{self.class.name} does not implement dependencies"
      end

      def mapped_params(params)
        result = params.except(:sort, :not_component_versions)
        result.merge!(SORT_TO_PARAMS_MAP.fetch(params[:sort], {}))

        if params[:not_component_versions].present?
          result[:not] =
            { component_versions: params[:not_component_versions] }
        end

        result
      end

      def track_event
        if project_or_namespace.is_a?(::Project)
          track_internal_event(
            "called_dependency_api",
            user: current_user,
            project: project_or_namespace,
            additional_properties: {
              label: 'graphql'
            }
          )
        elsif project_or_namespace.is_a?(::Group)
          track_internal_event(
            "called_dependency_api",
            user: current_user,
            namespace: project_or_namespace,
            additional_properties: {
              label: 'graphql'
            }
          )
        end
      end
    end
  end
end
