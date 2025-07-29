# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillZoektReplicas
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_zoekt_replicas
          scope_to ->(relation) { relation.where(zoekt_replica_id: nil) }
        end

        class EnabledNamespace < ::Gitlab::Database::Migration[2.2]::MigrationRecord
          self.table_name = 'zoekt_enabled_namespaces'
        end

        class Replica < ::Gitlab::Database::Migration[2.2]::MigrationRecord
          self.table_name = 'zoekt_replicas'

          def self.for_enabled_namespace!(zoekt_enabled_namespace)
            params = {
              namespace_id: zoekt_enabled_namespace.root_namespace_id,
              zoekt_enabled_namespace_id: zoekt_enabled_namespace.id
            }

            where(namespace_id: params[:namespace_id]).first || create!(params)
          rescue ActiveRecord::RecordInvalid => invalid
            raise unless invalid.record&.errors&.of_kind?(:namespace_id, :taken)

            Gitlab::BackgroundMigration::Logger.warn(message: 'Retrying zoekt first or create', error: invalid.message)
            retry
          end
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.each do |zkt_index|
              next if zkt_index.zoekt_replica_id.present?
              next if zkt_index.zoekt_enabled_namespace_id.nil?

              zkt_enabled_namespace = EnabledNamespace.find(zkt_index.zoekt_enabled_namespace_id)
              zkt_replica = Replica.for_enabled_namespace!(zkt_enabled_namespace)
              zkt_index.update!(zoekt_replica_id: zkt_replica.id)
            end
          end
        end
      end
    end
  end
end
