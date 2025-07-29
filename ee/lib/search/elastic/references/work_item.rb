# frozen_string_literal: true

module Search
  module Elastic
    module References
      class WorkItem < Reference
        include Search::Elastic::Concerns::DatabaseReference

        # Latest schema version - format is Date.today.strftime('%y_%w')
        # Update this when changing the document schema.
        # Only applies after migration completes to prevent indexing documents
        # with new schema before data migration finishes, which would result in
        # documents not being indexed properly and missing data.
        SCHEMA_VERSION = 25_29
        DEFAULT_INDEX_ATTRIBUTES = %i[
          id
          iid
          created_at
          updated_at
          title
          description
          author_id
          due_date
          confidential
          project_id
          state
        ].freeze

        PERMITTED_FILTER_KEYS = %i[
          order_by
          sort
          confidential
          state
          label_name
          label_names
          not_label_names
          or_label_names
          none_label_names
          any_label_names
          include_archived
          fields
          author_username
          not_author_username
          milestone_title
          not_milestone_title
          none_milestones
          any_milestones
          milestone_state_filters
          assignee_ids
          not_assignee_ids
          or_assignee_ids
          none_assignees
          any_assignees
          weight
          not_weight
          none_weight
          any_weight
          work_item_type_ids
          health_status
          not_health_status
          none_health_status
          any_health_status
        ].freeze

        override :serialize
        def self.serialize(record)
          new(record.id, record.es_parent).serialize
        end

        override :instantiate
        def self.instantiate(string)
          _, id, routing = delimit(string)

          # this puts the record in the work items index
          new(id, routing)
        end

        override :preload_indexing_data
        def self.preload_indexing_data(refs)
          ids = refs.map(&:identifier)

          records = ::WorkItem.id_in(ids).preload_indexing_data
          records_by_id = records.index_by(&:id)

          refs.each do |ref|
            ref.database_record = records_by_id[ref.identifier.to_i]
          end

          refs
        end

        def self.index
          environment_specific_index_name('work_items')
        end

        attr_reader :identifier, :routing

        def initialize(identifier, routing)
          @identifier = identifier.to_i
          @routing = routing
        end

        def schema_version
          if ::Elastic::DataMigrationService.migration_has_finished?(:index_work_items_milestone_state)
            SCHEMA_VERSION
          elsif ::Elastic::DataMigrationService.migration_has_finished?(:add_extra_fields_to_work_items)
            25_27
          else
            25_22 # Previous stable version until migration completes
          end
        end

        override :serialize
        def serialize
          self.class.join_delimited([klass, identifier, routing].compact)
        end

        override :operation
        def operation
          database_record ? :upsert : :delete
        end

        override :as_indexed_json
        def as_indexed_json
          build_indexed_json(database_record)
        end

        override :index_name
        def index_name
          self.class.index
        end

        def model_klass
          ::WorkItem
        end

        private

        def build_indexed_json(target)
          data = {}

          DEFAULT_INDEX_ATTRIBUTES.each do |attribute|
            data[attribute.to_s] = safely_read_attribute_for_elasticsearch(target, attribute)
          end

          data.merge!(build_extra_data(target))
          data.merge!(build_namespace_data(target))
          data.merge!(build_project_data(target))
          data.merge!(build_milestone_data(target))

          data.stringify_keys
        end

        def build_extra_data(target)
          extra_data = {
            label_ids: target.label_ids.map(&:to_s),
            hidden: target.hidden?,
            root_namespace_id: target.namespace.root_ancestor.id,
            traversal_ids: target.namespace.elastic_namespace_ancestry,
            hashed_root_namespace_id: target.namespace.hashed_root_namespace_id,
            work_item_type_id: target.work_item_type_id,
            assignee_id: safely_read_attribute_for_elasticsearch(target, :issue_assignee_user_ids),
            upvotes: target.upvotes_count,
            schema_version: schema_version,
            routing: routing,
            type: model_klass.es_type
          }

          unless ::Elastic::DataMigrationService.migration_has_finished?(:add_extra_fields_to_work_items)
            return extra_data
          end

          extra_data['closed_at'] = target.closed_at
          extra_data['weight'] = target.weight
          extra_data['health_status'] = target.health_status_for_database
          extra_data['label_names'] = target.labels&.map(&:title)

          extra_data
        end

        def build_namespace_data(target)
          return {} unless target.namespace.group_namespace?

          {
            namespace_visibility_level: target.namespace.visibility_level,
            namespace_id: target.namespace_id
          }
        end

        def build_project_data(target)
          return {} unless target.project.present?

          {
            archived: target.project.archived?,
            project_visibility_level: target.project.visibility_level,
            issues_access_level: target.project.issues_access_level
          }
        end

        def build_milestone_data(target)
          milestone_data = {}

          if ::Elastic::DataMigrationService.migration_has_finished?(:add_work_item_milestone_data)
            milestone_data.merge!({
              milestone_title: target.milestone&.title,
              milestone_id: target.milestone_id
            })
          end

          if ::Elastic::DataMigrationService.migration_has_finished?(:add_extra_fields_to_work_items)
            milestone_data['milestone_start_date'] = target.milestone&.start_date
            milestone_data['milestone_due_date'] = target.milestone&.due_date
          end

          if ::Elastic::DataMigrationService.migration_has_finished?(:index_work_items_milestone_state)
            milestone_data['milestone_state'] = target.milestone&.state
          end

          milestone_data
        end
      end
    end
  end
end
