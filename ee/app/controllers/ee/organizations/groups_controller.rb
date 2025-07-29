# frozen_string_literal: true

module EE
  module Organizations
    module GroupsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action :check_subscription!, only: [:destroy]
      end

      private

      def check_subscription!
        return unless group.linked_to_subscription?

        render json: { message: _('This group is linked to a subscription') }, status: :bad_request
      end
    end
  end
end
