# frozen_string_literal: true

module Resolvers
  module Security
    class VulnerabilitiesOverTimeResolver < VulnerabilitiesBaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_DATE_RANGE_DAYS = 1.year.in_days.floor.freeze

      type Types::Security::VulnerabilitiesOverTimeType.connection_type, null: true

      authorize :read_security_resource

      argument :start_date, GraphQL::Types::ISO8601Date,
        required: true,
        description: 'Start date for the vulnerability metrics time range.'

      argument :end_date, GraphQL::Types::ISO8601Date,
        required: true,
        description: 'End date for the vulnerability metrics time range.'

      def resolve(start_date:, end_date:, **args)
        authorize!(object) unless resolve_vulnerabilities_for_instance_security_dashboard?
        validate_date_range!(start_date, end_date)

        return [] if !vulnerable || Feature.disabled?(:group_security_dashboard_new, vulnerable)

        base_params = build_base_params(start_date, end_date, args)

        severity_results = fetch_grouped_results(base_params.merge(group_by: 'severity'))
        report_type_results = fetch_grouped_results(base_params.merge(group_by: 'report_type'))

        transform_results(severity_results, report_type_results)
      end

      private

      def build_base_params(start_date, end_date, args)
        {
          start_date: start_date,
          end_date: end_date,
          project_id: args[:project_id]
        }.compact
      end

      def fetch_grouped_results(params)
        finder = ::Security::VulnerabilityElasticCountOverTimeFinder.new(vulnerable, params)
        finder.execute
      end

      def validate_date_range!(start_date, end_date)
        raise Gitlab::Graphql::Errors::ArgumentError, "start date cannot be after end date" if start_date > end_date

        return unless (end_date - start_date) > MAX_DATE_RANGE_DAYS

        raise Gitlab::Graphql::Errors::ArgumentError, "maximum date range is #{MAX_DATE_RANGE_DAYS} days"
      end

      def transform_results(severity_results, report_type_results)
        return [] if severity_results.empty? && report_type_results.empty?

        date_map = {}

        process_results(severity_results, date_map) do |result, entry|
          entry[:by_severity] = transform_severity_data(result[:by_severity])
        end

        process_results(report_type_results, date_map) do |result, entry|
          entry[:by_report_type] = transform_report_type_data(result[:by_report_type])
        end

        date_map.values
      end

      def get_value(hash, key)
        return unless hash

        hash[key.to_s] || hash[key]
      end

      def process_results(results, date_map)
        results.each do |result|
          date_value = result[:date] || Time.zone.today # todo: what do we do if date is missing?
          date_key = date_value.to_s

          date_map[date_key] ||= {
            date: date_value,
            count: 0,
            by_severity: [],
            by_report_type: []
          }

          count = result[:count]
          date_map[date_key][:count] = count if date_map[date_key][:count] == 0

          yield(result, date_map[date_key]) if block_given?
        end
      end

      def transform_grouped_data(data, field_name)
        return [] unless data

        data.map do |item|
          value = get_value(item, field_name)
          value = value.downcase if value.is_a?(String)

          {
            field_name.to_sym => value,
            count: get_value(item, :count).to_i || 0
          }
        end
      end

      def transform_severity_data(severity_data)
        transform_grouped_data(severity_data, :severity)
      end

      def transform_report_type_data(report_type_data)
        transform_grouped_data(report_type_data, :report_type)
      end
    end
  end
end
