# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class RegistryUpstream < ApplicationRecord
        MAX_UPSTREAMS_COUNT = 20

        belongs_to :group
        belongs_to :registry,
          class_name: 'VirtualRegistries::Packages::Maven::Registry',
          inverse_of: :registry_upstreams
        belongs_to :upstream,
          class_name: 'VirtualRegistries::Packages::Maven::Upstream',
          inverse_of: :registry_upstreams

        validates :upstream_id, uniqueness: { scope: :registry_id }, if: :upstream_id?
        validates :registry_id, uniqueness: { scope: [:position] }

        validates :group, top_level_group: true, presence: true
        validates :position,
          numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_UPSTREAMS_COUNT },
          presence: true

        before_validation :set_group, :set_position, on: :create

        def self.sync_higher_positions(registry_upstreams)
          subquery = registry_upstreams.select(:registry_id, :position)

          joins("INNER JOIN (#{subquery.to_sql}) AS subquery ON #{table_name}.registry_id = subquery.registry_id")
            .where("#{table_name}.position > subquery.position")
            .update_all(position: Arel.sql('position - 1'))
        end

        def sync_higher_positions
          return if position == MAX_UPSTREAMS_COUNT

          self.class
            .where(registry_id: registry_id, position: (position + 1)..)
            .update_all(position: Arel.sql('position - 1'))
        end

        def update_position(new_position)
          return if position == new_position

          relation = self.class.where(registry_id:)

          capped_pos = [new_position, relation.maximum(:position)].min

          return if position == capped_pos

          arel_id = self.class.arel_table[:id]
          arel_pos = self.class.arel_table[:position]

          case_clause = Arel::Nodes::Case.new.when(arel_id.eq(id)).then(capped_pos)

          case_clause = if capped_pos > position
                          case_clause.when(arel_pos.between((position + 1)..capped_pos)).then(arel_pos - 1)
                        else
                          case_clause.when(arel_pos.between(capped_pos..(position - 1))).then(arel_pos + 1)
                        end.else(arel_pos)

          relation.update_all(position: case_clause)
        end

        private

        def set_group
          self.group ||= (registry || upstream).group
        end

        def set_position
          self.position = self.class.where(registry:, group:).maximum(:position).to_i + 1
        end
      end
    end
  end
end
