# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class Registry < ApplicationRecord
        MAX_REGISTRY_COUNT = 20

        belongs_to :group
        has_many :registry_upstreams,
          -> { order(position: :asc) },
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :registry
        has_many :upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::Upstream',
          through: :registry_upstreams

        validates :group, top_level_group: true, presence: true
        validates :name, presence: true, length: { maximum: 255 }
        validates :description, length: { maximum: 1024 }
        validates :group_id, uniqueness: { scope: :name }

        validate :max_per_group, on: :create

        scope :for_group, ->(group) { where(group: group) }

        before_destroy :delete_upstreams

        def exclusive_upstreams
          subquery = RegistryUpstream
            .where(RegistryUpstream.arel_table[:upstream_id].eq(Upstream.arel_table[:id]))
            .where.not(registry_id: id)

          Upstream
            .primary_key_in(registry_upstreams.select(:upstream_id).unscope(:order))
            .where_not_exists(subquery)
        end

        def purge_cache!
          ::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker.bulk_perform_async_with_contexts(
            exclusive_upstreams,
            arguments_proc: ->(upstream) { [upstream.id] },
            context_proc: ->(upstream) { { namespace: upstream.group } }
          )
        end

        private

        def max_per_group
          return if self.class.for_group(group).size < MAX_REGISTRY_COUNT

          errors.add(
            :group,
            format(_('%{count} registries is the maximum allowed per group.'), count: MAX_REGISTRY_COUNT)
          )
        end

        def delete_upstreams
          exclusive_upstreams.delete_all
        end
      end
    end
  end
end
