# frozen_string_literal: true

module Resolvers
  module Sbom
    class DependencyPathsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Sbom::DependencyPathPage, null: true

      authorize :read_dependency
      authorizes_object!

      argument :occurrence, Types::GlobalIDType[::Sbom::Occurrence],
        required: true,
        description: 'Dependency path for occurrence.'

      alias_method :project, :object

      argument :after, String, required: false,
        description: "Fetch paths after the cursor."

      argument :before, String, required: false,
        description: "Fetch paths before the cursor."

      argument :limit, Integer, required: false,
        description: "Number of paths to fetch."

      validates mutually_exclusive: [:after, :before]

      def resolve(**args)
        return if Feature.disabled?(:dependency_graph_graphql, project)

        occurrence_id = resolve_gid(args[:occurrence], ::Sbom::Occurrence)
        sbom_occurrence = project.sbom_occurrences.id_in(occurrence_id).first

        return unless sbom_occurrence

        # Decode cursors to path arrays
        after_ids = decode_cursor(args[:after]) if args[:after]
        before_ids = decode_cursor(args[:before]) if args[:before]
        limit = args[:limit]

        dependency_paths(sbom_occurrence, after_ids, before_ids, limit)
      end

      private

      def resolve_gid(gid, gid_class)
        Types::GlobalIDType[gid_class].coerce_isolated_input(gid).model_id
      end

      def decode_cursor(cursor)
        ::Gitlab::Json.parse(Base64.decode64(cursor))
      rescue JSON::ParserError => e
        raise GraphQL::ExecutionError, "Invalid cursor format: #{e.message}"
      end

      def dependency_paths(sbom_occurrence, after_ids, before_ids, limit)
        ::Sbom::PathFinder.execute(
          sbom_occurrence,
          after_graph_ids: after_ids,
          before_graph_ids: before_ids,
          limit: limit
        )
      end
    end
  end
end
