# frozen_string_literal: true

module Search
  module Zoekt
    class RolloutService
      include Gitlab::Loggable

      DEFAULT_OPTIONS = {
        num_replicas: 1,
        max_indices_per_replica: MAX_INDICES_PER_REPLICA,
        dry_run: true,
        batch_size: 128
      }.freeze

      Result = Data.define(:message, :changes, :re_enqueue)

      def self.execute(**kwargs)
        new(**kwargs).execute
      end

      attr_reader :num_replicas, :max_indices_per_replica, :batch_size, :dry_run

      def initialize(**kwargs)
        options = DEFAULT_OPTIONS.merge(kwargs)
        @num_replicas = options.fetch(:num_replicas)
        @max_indices_per_replica = options.fetch(:max_indices_per_replica)
        @dry_run = options.fetch(:dry_run)
        @batch_size = options.fetch(:batch_size)
      end

      def execute
        resource_pool = ::Search::Zoekt::SelectionService.execute(max_batch_size: batch_size)
        return Result.new('No enabled namespaces found', {}, false) if resource_pool.enabled_namespaces.empty?
        return Result.new('No available nodes found', {}, false) if resource_pool.nodes.empty?

        plan = ::Search::Zoekt::PlanningService.plan(
          enabled_namespaces: resource_pool.enabled_namespaces,
          nodes: resource_pool.nodes,
          num_replicas: num_replicas,
          max_indices_per_replica: max_indices_per_replica
        )
        logger.info(build_structured_payload(**{ zoekt_rollout_plan: ::Gitlab::Json.parse(plan.to_json) }))
        return Result.new('Skipping execution of changes because of dry run', {}, false) if dry_run

        changes = ::Search::Zoekt::ProvisioningService.execute(plan)
        result(changes)
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def result(changes = {})
        success = changes[:success]&.any?
        errors = changes[:errors]&.any?

        message, re_enqueue = if success && errors
                                ['Batch is completed with partial success', true]
                              elsif errors
                                ['Batch is completed with failure', false]
                              elsif success
                                ['Batch is completed with success', true]
                              else
                                ['Batch is completed without changes', true]
                              end

        Result.new(message, changes, re_enqueue)
      end
    end
  end
end
