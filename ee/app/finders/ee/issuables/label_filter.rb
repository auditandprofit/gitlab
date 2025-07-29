# frozen_string_literal: true

module EE
  module Issuables
    module LabelFilter
      extend ::Gitlab::Utils::Override

      SCOPED_LABEL_WILDCARD = '*'

      private

      override :find_label_ids_uncached
      def find_label_ids_uncached(label_names)
        return super unless root_namespace.licensed_feature_available?(:scoped_labels)

        scoped_label_wildcards, label_names = extract_scoped_label_wildcards(label_names)

        find_wildcard_label_ids(scoped_label_wildcards) + super(label_names)
      end

      override :target_label_links_query
      def target_label_links_query(target_model, base_target_model, label_ids)
        return super if parent.is_a?(Project)
        # Note that this is only correct for as long as we do not show issues/work items of type Epic
        # in issues list pages, otherwise this will resul in returning incomplete results when filtering by labels as
        # for Epic WorkItems labels can be linked either to legacy Epic records or Epic WorkItem records, by the
        # label_links.target_type for Epic WorkItems is set to `Issue`.
        # to be cleaned-up after we have:
        # - labels writes delegated from epic to epic work item: https://gitlab.com/gitlab-org/gitlab/-/issues/465725
        # - back-fill epic label links to work item label links: https://gitlab.com/groups/gitlab-org/-/epics/13021
        return super unless %w[Epic WorkItem].include?(target_model.name)

        multi_target_label_links_query(base_target_model, label_ids)
      end

      def extract_scoped_label_wildcards(label_names)
        label_names.partition { |name| name.ends_with?(::Label::SCOPED_LABEL_SEPARATOR + SCOPED_LABEL_WILDCARD) }
      end

      # This is similar to the CE version of `#find_label_ids_uncached` but the results
      # are grouped by the wildcard prefix. With nested scoped labels, a label can match multiple prefixes.
      # So a label_id can be present multiple times.
      #
      # For example, if we pass in `['workflow::*', 'workflow::backend::*']`, this will return something like:
      # `[ [1, 2, 3], [1, 2] ]`
      #
      # rubocop: disable CodeReuse/ActiveRecord
      def find_wildcard_label_ids(scoped_label_wildcards)
        return [] if scoped_label_wildcards.empty?

        scoped_label_prefixes = scoped_label_wildcards.map { |w| w.delete_suffix(SCOPED_LABEL_WILDCARD) }

        relations = scoped_label_prefixes.flat_map do |prefix|
          search_term = prefix + '%'

          [
            group_labels_for_root_namespace.where('title LIKE ?', search_term),
            project_labels_for_root_namespace.where('title LIKE ?', search_term)
          ]
        end

        labels = ::Label
          .from_union(relations, remove_duplicates: false)
          .without_order
          .pluck(:title, :id)

        group_by_prefix(labels, scoped_label_prefixes).values
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def group_by_prefix(labels, prefixes)
        labels.each_with_object({}) do |(title, id), ids_by_prefix|
          prefixes.each do |prefix|
            next unless title.start_with?(prefix)

            ids_by_prefix[prefix] ||= []
            ids_by_prefix[prefix] << id
          end
        end
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def multi_target_label_links_query(target_model, label_ids)
        case target_model.name
        when 'Epic'
          sync_model = ::Issue
          join_clause = target_model.arel_table['issue_id']

          ::LabelLink.from_union(
            [
              ::LabelLink.by_target_for_exists_query(target_model.name, target_model.arel_table['id'], label_ids),
              ::LabelLink.by_target_for_exists_query(sync_model.name, join_clause, label_ids)
            ],
            remove_duplicates: false
          )
        when 'Issue'
          sync_model = ::Epic
          join_clause = sync_model.arel_table.project(sync_model.arel_table['id']).where(
            sync_model.arel_table['issue_id'].eq(target_model.arel_table['id'])
          )

          ::LabelLink.from_union(
            [
              ::LabelLink.by_target_for_exists_query(target_model.name, target_model.arel_table['id'], label_ids),
              ::LabelLink.by_target_for_exists_query(sync_model.name, join_clause, label_ids)
            ],
            remove_duplicates: false
          )
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
