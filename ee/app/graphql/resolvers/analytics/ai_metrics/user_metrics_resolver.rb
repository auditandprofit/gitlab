# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetrics
      class UserMetricsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Analytics::AiMetrics::UserMetricsType, null: true

        authorizes_object!
        authorize :read_enterprise_ai_analytics

        argument :start_date, Types::DateType,
          required: false,
          description: 'Date range to start from. Default is the beginning of current month.'

        argument :end_date, Types::DateType,
          required: false,
          description: 'Date range to end at. Default is the end of current month.'

        def ready?(**args)
          validate_params!(args)

          super
        end

        def resolve(**args)
          context[:ai_metrics_params] = params_with_defaults(args).merge(namespace: namespace)

          ::GitlabSubscriptions::AddOnAssignedUsersFinder.new(
            current_user, namespace, add_on_name: :duo_enterprise).execute
        end

        private

        def validate_params!(args)
          params = params_with_defaults(args)

          return unless params[:start_date] < params[:end_date] - 1.year

          raise Gitlab::Graphql::Errors::ArgumentError, 'maximum date range is 1 year'
        end

        def params_with_defaults(args)
          { start_date: Time.current.beginning_of_month, end_date: Time.current.end_of_month }.merge(args)
        end

        def namespace
          object.try(:project_namespace) || object
        end
      end
    end
  end
end
