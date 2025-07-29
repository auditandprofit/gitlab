# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationHelper
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :organization_activity_app_data
      def organization_activity_app_data(organization)
        ::Gitlab::Json.parse(super).merge(
          organization_activity_event_types: organization_activity_event_types
        ).to_json
      end

      private

      override :organization_activity_event_types
      def organization_activity_event_types
        super.concat([
          {
            title: _('Epic'),
            value: EventFilter::EPIC
          }
        ]).sort_by { |event| event[:value] }
      end
    end
  end
end
