# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillReservedStorageBytes
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        BUFFER_FACTOR = 3
        DEFAULT_SIZE = 10.gigabytes

        prepended do
          operation_name :backfill_reserved_storage_bytes_zoekt_indices
          scope_to ->(relation) { relation.where(reserved_storage_bytes: nil) }
        end

        class EnabledNamespace < ::Gitlab::Database::Migration[2.2]::MigrationRecord
          self.table_name = 'zoekt_enabled_namespaces'
        end

        class Namespace < ::Gitlab::Database::Migration[2.2]::MigrationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled
        end

        class Namespace
          class RootStorageStatistics < ::Gitlab::Database::Migration[2.2]::MigrationRecord
            self.table_name = 'namespace_root_storage_statistics'
          end
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.each do |zkt_index|
              next if zkt_index.reserved_storage_bytes.present?
              next if zkt_index.zoekt_enabled_namespace_id.nil?

              zoekt_enabled_namespace = EnabledNamespace.find_by_id(zkt_index.zoekt_enabled_namespace_id)
              next if zoekt_enabled_namespace.nil?

              namespace = Namespace.find_by_id(zoekt_enabled_namespace.root_namespace_id)
              next if namespace.nil?

              storage_statistics = Namespace::RootStorageStatistics.find_by(namespace_id: namespace.id)
              size = storage_statistics.nil? ? DEFAULT_SIZE : BUFFER_FACTOR * storage_statistics.repository_size
              zkt_index.update!(reserved_storage_bytes: size)
            end
          end
        end
      end
    end
  end
end
