# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      # This class is responsible for injecting custom stages from multiple pipelines
      # into stages of a single pipeline. It uses DAG ordering to merge the stages.
      class StagesMerger
        InvalidStageConditionError = Class.new(StandardError)

        class << self
          # @param original_stages [Array] Original stages
          # @param stages_to_merge [Array<Array>] List of stages for each pipeline we merge
          # @return [Array] Merged project and other pipeline stages
          def inject(original_stages, stages_to_merge)
            project_tree = generate_tree(original_stages)
            other_pipelines_trees = stages_to_merge.flat_map do |stages|
              generate_tree(stages)
            end

            dependency_tree = merge_trees([project_tree, *other_pipelines_trees])
            ::Gitlab::Ci::YamlProcessor::Dag.order(dependency_tree) # rubocop:disable CodeReuse/ActiveRecord -- not an ActiveRecord object
          rescue TSort::Cyclic
            raise InvalidStageConditionError, 'Cyclic dependencies detected. ' \
              'Ensure stages across all pipelines are aligned.' \
          end

          private

          def generate_tree(stages)
            stages.each_with_object({}).with_index do |(stage, tree), index|
              # Build a map where each stage has a dependency on all of its previous stages.
              previous_stages = stages[0...index]
              tree[stage] = previous_stages
            end
          end

          def merge_trees(trees)
            trees.each_with_object({}) do |tree, hash|
              tree.each do |stage, dependencies|
                # Merge dependencies of each stage from all pipelines.
                # This allows us to catch cyclic dependencies when we merge trees for each pipeline.
                # When we perform `Dag.order`, each stage is placed after all stages it depends on.
                hash[stage] = Array.wrap(hash[stage]) | dependencies
              end
            end
          end
        end
      end
    end
  end
end
