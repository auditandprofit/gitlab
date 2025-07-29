# frozen_string_literal: true

module Resolvers
  module Analytics
    module ProductAnalytics
      class ProjectSettingsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorizes_object!
        authorize :maintainer_access
        type ::Types::Analytics::ProductAnalytics::ProductAnalyticsProjectSettingsType, null: true

        def resolve
          return unless Gitlab::CurrentSettings.product_analytics_enabled? && project.product_analytics_enabled?

          project.project_setting
        end

        private

        def project
          object.respond_to?(:sync) ? object.sync : object
        end
      end
    end
  end
end
