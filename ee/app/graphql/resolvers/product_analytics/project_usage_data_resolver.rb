# frozen_string_literal: true

module Resolvers
  module ProductAnalytics
    class ProjectUsageDataResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      authorizes_object!
      authorize :maintainer_access
      type [::Types::ProductAnalytics::MonthlyUsageType], null: true

      argument :month_selection, [::Types::ProductAnalytics::MonthSelectionInputType],
        required: true, description: 'Selection for the period to return.'

      def resolve(month_selection: [])
        month_selection.map do |selection|
          year = selection[:year]
          month = selection[:month]
          {
            year: year,
            month: month,
            count: object.product_analytics_events_used(year: year, month: month)
          }
        end
      end
    end
  end
end
