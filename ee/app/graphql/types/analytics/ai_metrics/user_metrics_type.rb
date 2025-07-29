# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      class UserMetricsType < BaseObject
        graphql_name 'AiUserMetrics'
        description "Pre-aggregated per-user metrics for GitLab Code Suggestions and GitLab Duo Chat. " \
          "Require ClickHouse to be enabled and GitLab Ultimate with the Duo Enterprise add-on."

        field :code_suggestions_accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted by the user.',
          null: true
        field :duo_chat_interactions_count, GraphQL::Types::Int,
          description: 'Number of user interactions with GitLab Duo Chat.',
          null: true
        field :user, Types::GitlabSubscriptions::AddOnUserType,
          description: 'User associated with metrics.',
          null: false

        alias_method :user, :object

        def code_suggestions_accepted_count
          batch_loader_for(:code_suggestions_accepted_count)
        end

        def duo_chat_interactions_count
          batch_loader_for(:duo_chat_interactions_count)
        end

        private

        def batch_loader_for(field)
          BatchLoader::GraphQL.for(user).batch(key: field) do |users, callback|
            metrics = metrics_data(users)
            users.each do |user|
              user_metrics = metrics[user.id]
              callback.call(user, (user_metrics && user_metrics[field]) || 0)
            end
          end
        end

        def metrics_data(users)
          @metrics_data ||= ::Analytics::AiAnalytics::AiUserMetricsService.new(
            current_user,
            user_ids: users.map(&:id),
            namespace: context[:ai_metrics_params][:namespace],
            from: context[:ai_metrics_params][:start_date],
            to: context[:ai_metrics_params][:end_date]
          ).execute.payload
        end
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
