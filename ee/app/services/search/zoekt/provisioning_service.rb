# frozen_string_literal: true

module Search
  module Zoekt
    class ProvisioningService
      def self.execute(plan)
        new(plan).execute
      end

      attr_reader :plan, :errors

      def initialize(plan)
        @plan = plan
        @errors = []
        @success = []
      end

      def execute
        plan[:failures].each { |failed_nanespace_plan| update_enabled_namespace(failed_nanespace_plan) }
        plan[:namespaces].each do |namespace_plan|
          ApplicationRecord.transaction do
            # result will either be nil or an array of replicas. If it is an array of replicas, that means we
            # successfully provisioned all replicas for the namespace. In such a case, we reset the metadata.
            result = process_namespace(namespace_plan)
            update_enabled_namespace(namespace_plan, reset: result.present?)
          end
        rescue NodeStorageError => e
          update_enabled_namespace(namespace_plan)
          json = Gitlab::Json.parse(e.message, symbolize_names: true)
          aggregate_error(json[:message], failed_namespace_id: json[:namespace_id], node_id: json[:node_id])
        rescue StandardError => e
          update_enabled_namespace(namespace_plan)
          aggregate_error(e.message)
        end
        { errors: @errors, success: @success }
      end

      private

      def process_namespace(namespace_plan)
        namespace_id = namespace_plan.fetch(:namespace_id)
        # Remove any pre-existing replicas for this namespace since we are provisioning new ones.
        enabled_namespace = Search::Zoekt::EnabledNamespace.for_root_namespace_id(namespace_id).first
        if enabled_namespace.nil?
          aggregate_error(:missing_enabled_namespace, failed_namespace_id: namespace_id)
          return
        end

        enabled_namespace.replicas.delete_all

        if Index.for_root_namespace_id(namespace_id).exists?
          aggregate_error(:index_already_exists, failed_namespace_id: namespace_id)
          return
        end

        enabled_namespace_id = namespace_plan.fetch(:enabled_namespace_id)
        namespace_plan[:replicas].each do |replica_plan|
          process_replica(
            namespace_id: namespace_id,
            enabled_namespace_id: enabled_namespace_id,
            replica_plan: replica_plan
          )
        end
      end

      def process_replica(namespace_id:, enabled_namespace_id:, replica_plan:)
        replica = Replica.create!(namespace_id: namespace_id, zoekt_enabled_namespace_id: enabled_namespace_id)
        process_indices!(replica, replica_plan[:indices])
      end

      def process_indices!(replica, indices_plan)
        zoekt_indices = indices_plan.map do |index_plan|
          node = Node.find(index_plan[:node_id])
          required_storage_bytes = index_plan[:required_storage_bytes]
          if required_storage_bytes > node.unclaimed_storage_bytes
            raise NodeStorageError, {
              message: 'node_capacity_exceeded', namespace_id: replica.namespace_id, node_id: node.id
            }.to_json
          end

          {
            zoekt_enabled_namespace_id: replica.zoekt_enabled_namespace_id,
            zoekt_replica_id: replica.id,
            zoekt_node_id: node.id,
            namespace_id: replica.namespace_id,
            reserved_storage_bytes: required_storage_bytes,
            metadata: index_plan[:projects].compact
          } # Workaround: we remove nil project_namespace_id_to since it is not a valid property in json validator.
        end
        Index.insert_all(zoekt_indices)
        aggregate_success(replica)
      end

      def aggregate_error(message, failed_namespace_id: nil, node_id: nil)
        @errors << { message: message, failed_namespace_id: failed_namespace_id, node_id: node_id }
      end

      def aggregate_success(replica)
        @success << { namespace_id: replica.namespace_id, replica_id: replica.id }
      end

      def update_enabled_namespace(namespace_plan, reset: false)
        enabled_ns = EnabledNamespace.for_root_namespace_id(namespace_plan[:namespace_id]).with_limit(1).first
        return unless enabled_ns

        if reset
          enabled_ns.last_rollout_failed_at = nil
        else
          enabled_ns.last_rollout_failed_at = Time.current.iso8601
          enabled_ns.metadata['rollout_required_storage_bytes'] = namespace_plan[:namespace_required_storage_bytes]
        end

        enabled_ns.save!
      end
    end

    NodeStorageError = Class.new(StandardError)
  end
end
