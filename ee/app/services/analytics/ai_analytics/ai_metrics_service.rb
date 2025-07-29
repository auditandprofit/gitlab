# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class AiMetricsService
      attr_reader :current_user, :namespace, :from, :to, :fields

      def initialize(current_user, namespace:, from:, to:, fields:)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = fields
      end

      def execute
        data = add_duo_assigned({})
        data = add_usage(data, CodeSuggestionUsageService, DuoChatUsageService, DuoUsageService,
          TroubleshootUsageService)

        ServiceResponse.success(payload: data)
      end

      private

      def add_duo_assigned(data)
        return data unless fields.include?(:duo_assigned_users_count)

        # TODO: Refactor after https://gitlab.com/gitlab-org/gitlab/-/issues/489759 is done.
        # current code assumes that addons are mutually exclusive
        pro_users = GitlabSubscriptions::AddOnAssignedUsersFinder.new(
          current_user, namespace, add_on_name: :code_suggestions).execute

        enterprise_users = GitlabSubscriptions::AddOnAssignedUsersFinder.new(
          current_user, namespace, add_on_name: :duo_enterprise).execute

        data.merge(duo_assigned_users_count: pro_users.count + enterprise_users.count)
      end

      def add_usage(data, *service_classes)
        service_classes.each do |klass|
          usage = klass.new(
            current_user,
            namespace: namespace,
            from: from,
            to: to,
            fields: fields
          ).execute

          data.merge!(usage.payload) if usage.success?
        end

        data
      end
    end
  end
end
