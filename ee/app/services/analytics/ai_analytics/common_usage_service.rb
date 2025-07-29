# frozen_string_literal: true

module Analytics
  module AiAnalytics
    module CommonUsageService
      include Gitlab::Utils::StrongMemoize

      CONTRIBUTORS_FILTER_REGEX_PATTERN = /where user_id in \(select author_id from contributors\)/i
      NAMESPACE_PATH_FILTER = 'WHERE startsWith(namespace_path, {traversal_path:String})'

      def initialize(current_user, namespace:, from:, to:, fields: nil)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = (fields & self.class::FIELDS) || self.class::FIELDS
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)
        return ServiceResponse.success(payload: {}) unless fields.present?

        ServiceResponse.success(payload: usage_data.symbolize_keys!)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :fields

      def fetch_contributions_from_new_table?
        Feature.enabled?(:fetch_contributions_data_from_new_tables, namespace)
      end
      strong_memoize_attr :fetch_contributions_from_new_table?

      def filter_by_namespace_path_enabled?
        Feature.enabled?(:use_ai_events_namespace_path_filter, namespace)
      end

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def placeholders
        {
          traversal_path: namespace.traversal_path(with_organization: fetch_contributions_from_new_table?),
          from: from.to_date.iso8601,
          to: to.to_date.iso8601
        }
      end

      def usage_data
        new_query = replace_contributors_filter(raw_query)

        query = ClickHouse::Client::Query.new(raw_query: new_query, placeholders: placeholders)

        ClickHouse::Client.select(query, :main).first
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{self.class::FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        format(base_query, fields: raw_fields)
      end

      def replace_contributors_filter(old_query)
        return old_query unless filter_by_namespace_path_enabled?

        old_query.gsub(CONTRIBUTORS_FILTER_REGEX_PATTERN, NAMESPACE_PATH_FILTER)
      end

      # We can remove this base query filtering by contributors
      # after use_ai_events_namespace_path_filter rollout.
      def base_query
        if fetch_contributions_from_new_table?
          self.class::NEW_QUERY
        else
          self.class::QUERY
        end
      end
    end
  end
end
