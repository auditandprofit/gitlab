# frozen_string_literal: true

module Elastic
  module Latest
    class IssueInstanceProxy < ApplicationInstanceProxy
      SCHEMA_VERSION = 24_08
      OPTIONAL_FIELDS = %w[embedding embedding_version].freeze

      def as_indexed_json(_options = {})
        data = {}

        return data unless target.project_id

        # We don't use as_json(only: ...) because it calls all virtual and serialized attributes
        # https://gitlab.com/gitlab-org/gitlab/issues/349
        [:id, :iid, :title, :description, :created_at, :updated_at, :state, :project_id, :author_id,
          :confidential].each do |attr|
          data[attr.to_s] = safely_read_attribute_for_elasticsearch(attr)
        end

        # Schema version. The format is Date.today.strftime('%y_%m')
        # Please update if you're changing the schema of the document
        data['schema_version'] = SCHEMA_VERSION

        # Load them through the issue_assignees table since calling
        # assignee_ids can't be easily preloaded and does
        # unnecessary joins
        data['assignee_id'] = safely_read_attribute_for_elasticsearch(:issue_assignee_user_ids)
        data['hidden'] = target.hidden?
        data['visibility_level'] = target.project.visibility_level
        data['issues_access_level'] = safely_read_project_feature_for_elasticsearch(:issues)

        data['upvotes'] = target.upvotes_count
        data['namespace_ancestry_ids'] = target.namespace_ancestry
        data['label_ids'] = target.label_ids.map(&:to_s)

        data['hashed_root_namespace_id'] = target.project.namespace.hashed_root_namespace_id
        data['archived'] = target.project.archived?
        data['work_item_type_id'] = target.work_item_type_id

        data['routing'] = es_parent

        data.merge(generic_attributes)
      end

      def es_id
        target.id.to_s
      end

      private

      def generic_attributes
        super.except('join_field')
      end
    end
  end
end
