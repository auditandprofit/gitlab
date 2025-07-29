# frozen_string_literal: true

module Banzai
  module Filter
    module References
      class IterationsCadenceReferenceFilter < AbstractReferenceFilter
        self.reference_type = :iterations_cadence
        self.object_class = ::Iterations::Cadence

        def object_sym
          :iterations_cadence
        end

        def parent_type
          :group
        end

        def group
          context[:group] || context[:project]&.group
        end

        def find_object(parent_object, id)
          key = reference_cache.records_per_parent[parent_object].keys.find do |k|
            k[:cadence_id] == id[:cadence_id] || k[:cadence_title] == id[:cadence_title]
          end

          reference_cache.records_per_parent[parent_object][key] if key
        end

        def parent_records(parent, ids)
          return ::Iterations::Cadence.none unless parent.is_a?(Group)

          cadence_ids = ids.filter_map { |y| y[:cadence_id] }
          id_relation = find_cadences(parent, ids: cadence_ids) unless cadence_ids.empty?

          cadence_titles = ids.filter_map { |y| y[:cadence_title] }
          title_relation = find_cadences(parent, titles: cadence_titles) unless cadence_titles.empty?

          relation = [id_relation, title_relation].compact

          return ::Iterations::Cadence.none if relation.all?(::Iterations::Cadence.none)

          ::Iterations::Cadence.from_union(relation)
        end

        def parse_symbol(symbol, match_data)
          return { cadence_id: symbol.to_i, cadence_title: nil } if symbol

          { cadence_id: match_data[:cadence_id]&.to_i, cadence_title: match_data[:cadence_title]&.tr('"', '') }
        end

        # This method has the contract that if a string `ref` refers to a
        # record `record`, then `class.parse_symbol(ref) == record_identifier(record)`.
        # See note in `parse_symbol` above
        def record_identifier(record)
          { cadence_id: record.id, cadence_title: record.title }
        end

        def references_in(text, pattern = object_class.reference_pattern)
          cadences = {}

          unescaped_html = unescape_html_entities(text).gsub(pattern).with_index do |match, index|
            ident = identifier($~)
            cadence = yield match, ident, nil, nil, $~

            next match if cadence == match

            cadences[index] = cadence

            "#{::Banzai::Filter::References::AbstractReferenceFilter::REFERENCE_PLACEHOLDER}#{index}"
          end

          return text if cadences.empty?

          escape_with_placeholders(unescaped_html, cadences)
        end

        def url_for_object(cadence, group)
          ::Gitlab::Routing.url_helpers.group_iteration_cadences_url(group, cadence, only_path: context[:only_path])
        end

        def reference_class(object_sym, tooltip: false)
          super
        end

        def object_link_text(object, matches)
          escape_once(super)
        end

        def requires_unescaping?
          true
        end

        private

        def find_cadences(parent, ids: nil, titles: nil)
          finder_params = cadence_finder_params(ids: ids, titles: titles)

          ::Iterations::CadencesFinder.new(user, parent, finder_params).execute(skip_authorization: true)
        end

        def cadence_finder_params(ids: nil, titles: nil)
          params = ids.present? ? { id: ids } : { exact_title: titles }

          { include_ancestor_groups: true }.merge(params)
        end
      end
    end
  end
end
