# frozen_string_literal: true

module Groups
  module Security
    class ConfigurationController < Groups::ApplicationController
      layout 'group'

      before_action :authorize_admin_security_attributes!

      feature_category :security_asset_inventories

      def show; end

      private

      def authorize_admin_security_attributes!
        render_403 unless
          can?(current_user, :admin_security_attributes, group) &&
            Feature.enabled?(:security_context_labels, group.root_ancestor) &&
            group.licensed_feature_available?(:security_attributes)
      end
    end
  end
end
