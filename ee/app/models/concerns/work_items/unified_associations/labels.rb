# frozen_string_literal: true

module WorkItems
  module UnifiedAssociations
    module Labels
      extend ActiveSupport::Concern

      included do
        has_many :own_label_links, class_name: 'LabelLink', as: :target, inverse_of: :target
        has_many :own_labels, through: :own_label_links

        has_many :label_links, as: :target, inverse_of: :target, dependent: :delete_all do # rubocop:disable Cop/ActiveRecordDependent -- Polymorphic association, so no FK
          def load_target
            return super unless proxy_association.owner.unified_associations?

            proxy_association.target = scope.to_a unless proxy_association.loaded?

            proxy_association.loaded!
            proxy_association.target
          end

          def find(*args)
            return super unless proxy_association.owner.unified_associations?
            return super if block_given?

            scope.find(*args)
          end

          # important to have this method overwritten as most collection proxy method methods are delegated to the scope
          def scope
            LabelLink.from_union(
              [
                proxy_association.owner.sync_object&.own_label_links || LabelLink.none,
                proxy_association.owner.own_label_links
              ],
              remove_duplicates: true
            )
          end
        end

        has_many :labels, through: :label_links do
          def load_target
            return super unless proxy_association.owner.unified_associations?

            proxy_association.target = scope.to_a unless proxy_association.loaded?

            proxy_association.loaded!
            proxy_association.target
          end

          def find(*args)
            return super unless proxy_association.owner.unified_associations?
            return super if block_given?

            scope.find(*args)
          end

          def replace(other_array)
            return super unless proxy_association.owner.unified_associations?

            to_be_removed = proxy_association.target - other_array
            to_be_added = other_array - proxy_association.target

            links_scope = LabelLink.from_union(
              [
                proxy_association.owner.own_label_links,
                proxy_association.owner.sync_object&.own_label_links
              ]
            ).where(label_id: to_be_removed)

            LabelLink.id_in(links_scope.select(:id)).delete_all unless to_be_removed.blank?

            proxy_association.target -= to_be_removed
            proxy_association.concat(to_be_added)

            self
          end

          # important to have this method overwritten as most collection proxy method methods are delegated to the scope
          def scope
            Label.from_union(
              [
                proxy_association.owner.sync_object&.own_labels || Label.none,
                proxy_association.owner.own_labels
              ],
              remove_duplicates: true
            )
          end
        end

        def labels=(array)
          if !try(:sync_object) || !unified_associations?
            super

            return
          end

          labels.replace(array)
        end

        def label_ids=(array)
          if !try(:sync_object) || !unified_associations?
            super

            return
          end

          labels.replace(Label.id_in(array).to_a)
        end

        def label_ids
          return super if !try(:sync_object) || !unified_associations?

          lazy_labels.itself.pluck(:id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- few labels
        end

        def lazy_labels
          return labels unless unified_associations?

          BatchLoader.for(batched_object).batch(cache: false) do |ids, loader, _args|
            objects_relation = self.class.id_in(ids.map(&:first).flat_map(&:first))
            sync_objects_relation = sync_object&.class&.id_in(ids.map(&:second).flat_map(&:first))

            labels = unified_labels(objects_relation, sync_objects_relation)

            ids.each do |ids_pair|
              loader.call(ids_pair, [labels[ids_pair[0]], labels[ids_pair[1]]].flatten.compact || [])
            end
          end
        end

        def unified_labels(objects_relation, sync_objects_relation)
          ::Label.from_union(
            [
              ::Label.for_targets(objects_relation),
              ::Label.for_targets(sync_objects_relation)
            ],
            remove_duplicates: true
          ).with_preloaded_container.group_by { |label| [label.target_id, label.target_type] }
        end
      end
    end
  end
end
