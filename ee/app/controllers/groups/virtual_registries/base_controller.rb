# frozen_string_literal: true

module Groups
  module VirtualRegistries
    class BaseController < Groups::ApplicationController
      include VirtualRegistryHelper

      before_action :ensure_feature!

      private

      def ensure_feature!
        render_404 unless @group.root?
        render_404 unless ::Feature.enabled?(:maven_virtual_registry, @group)
        render_404 unless ::Feature.enabled?(:ui_for_virtual_registries, @group)
        render_404 unless ::Gitlab.config.dependency_proxy.enabled
        render_404 unless @group.licensed_feature_available?(:packages_virtual_registry)
      end

      def verify_read_virtual_registry!
        access_denied! unless can?(current_user, :read_virtual_registry, @group.virtual_registry_policy_subject)
      end

      def verify_create_virtual_registry!
        access_denied! unless can_create_virtual_registry?(@group)
      end

      def verify_update_virtual_registry!
        access_denied! unless can?(current_user, :update_virtual_registry, @group.virtual_registry_policy_subject)
      end

      def verify_destroy_virtual_registry!
        access_denied! unless can_destroy_virtual_registry?(@group)
      end
    end
  end
end
