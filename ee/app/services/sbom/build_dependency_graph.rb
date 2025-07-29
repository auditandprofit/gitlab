# frozen_string_literal: true

module Sbom
  class BuildDependencyGraph
    include Gitlab::Utils::StrongMemoize

    BATCH_SIZE = 250

    def self.execute(project)
      new(project).execute
    end

    def initialize(project)
      @project = project
      @cache_key_service = Sbom::LatestGraphTimestampCacheKey.new(project: project)
    end

    def timestamp
      Time.zone.now
    end
    strong_memoize_attr :timestamp

    def execute
      new_graph = build_dependency_graph

      # This can raise ActiveRecord::RecordInvalid because another Ci::Pipeline can start removing Sbom::Occurrence
      # rows which will prevent this job from finishing successfully.
      #
      # This actually works in our favour since it's a clear indication we can leave the graph processing to the
      # newest job.
      bulk_insert_paths(new_graph)

      @cache_key_service.store(new_graph.first.created_at) unless new_graph.empty?

      # Schedule removal, this job is idempotent and deduplicated so we can schedule it many times
      Sbom::RemoveOldDependencyGraphsWorker.perform_async(project.id)
    end

    private

    attr_reader :project

    def build_dependency_graph
      direct_dependencies = sbom_occurrences.select(&:top_level?)

      all_paths = []

      # Process each occurrence to find direct parent-child relationships
      sbom_occurrences.each do |occurrence|
        next if occurrence.ancestors.empty?

        occurrence.ancestors.each do |ancestor|
          next if ancestor.empty?

          ancestor_name = ancestor['name']
          ancestor_version = ancestor['version']

          parent_occurrence = find_parent_sbom_occurrence(
            ancestor_name,
            ancestor_version,
            occurrence.input_file_path
          )

          next unless parent_occurrence

          # Create a direct path
          all_paths << Sbom::GraphPath.new(
            ancestor_id: parent_occurrence.id,
            descendant_id: occurrence.id,
            project_id: project.id,
            path_length: 1,
            created_at: timestamp,
            updated_at: timestamp,
            top_level_ancestor: parent_occurrence.top_level?
          )
        end
      end

      # Build an adjacency list from the direct paths
      graph = {}
      all_paths.each do |path|
        graph[path[:ancestor_id]] ||= []
        graph[path[:ancestor_id]] << path[:descendant_id]
      end

      transitive_paths = []

      # For each direct dependency, find all possible paths to other dependencies
      direct_dependencies.each do |direct_dep|
        find_all_paths(direct_dep.id, graph, transitive_paths)
      end

      result = all_paths
        .concat(transitive_paths)
        .uniq { |path| [path.ancestor_id, path.descendant_id, path.path_length] }

      ::Gitlab::AppLogger.info(
        message: "New graph creation complete",
        project: project.name,
        project_id: project.id,
        namespace: project.group&.name,
        namespace_id: project.group&.id,
        count_path_nodes: result.count
      )

      result
    end

    def bulk_insert_paths(paths)
      paths.each_slice(BATCH_SIZE) do |slice|
        Sbom::GraphPath.bulk_insert!(slice)
      end
    end

    def sbom_occurrences
      Sbom::Occurrence.by_project_ids(project.id).with_version.order_by_id
    end
    strong_memoize_attr :sbom_occurrences

    # Recursive Depth First Search to find all possible paths
    def find_all_paths(
      current_id, graph, all_paths, visited = Set.new, path_start = nil,
      current_length = 0)
      # Record the starting node if this is the beginning of a path
      path_start ||= current_id

      # Add current node to visited set to avoid cycles
      visited = visited.clone
      visited.add(current_id)

      # Get all direct neighbors
      neighbors = graph[current_id] || []

      new_length = current_length + 1

      neighbors.each do |neighbor_id|
        next if visited.include?(neighbor_id)

        if new_length > 1
          all_paths << Sbom::GraphPath.new(
            ancestor_id: path_start,
            descendant_id: neighbor_id,
            project_id: project.id,
            path_length: new_length,
            created_at: timestamp,
            updated_at: timestamp,
            top_level_ancestor: true # path start is always a top_level occurrence here.
          )
        end

        find_all_paths(neighbor_id, graph, all_paths, visited, path_start, new_length)
      end
    end

    # This is convoluted *but*:
    # `Sbom::Occurrence#ancestors` is `Array[Hash]`.
    # Every Hash is { "name": "something", "version": "something" }.
    # We need to find corresponding Sbom::Occurrence for that particular pair (Node, for example, allows two
    # versions of the same package in a single project)
    # This, usually, should give you exactly one record except it doesn't because monorepos are a thing
    # (it's perfectly fine to have two Rails applications depending on `activesupport`).
    def find_parent_sbom_occurrence(ancestor_name, ancestor_version, child_input_file_path)
      sbom_occurrences
        .find do |occurrence|
          occurrence.component_name.eql?(ancestor_name) &&
            occurrence.input_file_path.eql?(child_input_file_path) &&
            occurrence.version.eql?(ancestor_version)
        end
    end
  end
end
