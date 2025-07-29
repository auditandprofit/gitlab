# frozen_string_literal: true

module Resolvers
  module Analytics
    module CycleAnalytics
      module Concerns
        module IssuableStageResolver
          extend ActiveSupport::Concern

          def resolve(**args)
            metric = self.class::METRIC_CLASS.new(
              stage: ::Analytics::CycleAnalytics::Stage.new(namespace: namespace),
              current_user: current_user,
              options: process_params(args)
            )

            formatted_data(metric)
          end

          def authorized?(*)
            ::Gitlab::Analytics::CycleAnalytics.licensed?(namespace) && ::Gitlab::Analytics::CycleAnalytics.allowed?(
              current_user, namespace)
          end

          private

          included do
            alias_method :namespace, :object
          end

          def process_params(params)
            params[:not] = normalize_params(params[:not].to_h) if params[:not]
            params = normalize_params(params)
            params[:projects] = params[:project_ids] if params[:project_ids]
            params[:use_aggregated_data_collector] = true

            params
          end

          def normalize_params(params)
            assignees_value = params.delete(:assignee_usernames)
            params[:assignee_username] = assignees_value if assignees_value.present?
            params[:label_name] = params.delete(:label_names) if params[:label_names]
            params
          end

          def formatted_data(metric)
            value = metric.raw_value

            {
              value: value,
              unit: n_('day', 'days', value),
              links: metric.links
            }
          end
        end
      end
    end
  end
end
