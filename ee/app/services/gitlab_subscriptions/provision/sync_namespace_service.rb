# frozen_string_literal: true

# Service for syncing namespace provisions from CustomersDot
# @param namespace [Group] the namespace to sync
# @param params [Hash] provision params containing:
#   - event_type [String] must be "sync"
#   - base_product [Hash] plan parameters
#   - storage [Hash] storage parameters
#   - compute_minutes [Hash] compute minutes parameters
module GitlabSubscriptions
  module Provision
    class SyncNamespaceService
      attr_reader :namespace, :params

      def initialize(namespace:, params:)
        @namespace = namespace
        @params = params
        @errors = []
      end

      def execute
        sync_base_product
        sync_storage
        sync_compute_minutes
        sync_add_on_purchases

        return ServiceResponse.success if errors.blank?

        ServiceResponse.error(message: errors.flatten.join(', '))
      end

      private

      attr_reader :errors

      def base_product_params
        params[:base_product]
      end

      def compute_minutes_params
        params[:compute_minutes]
      end

      def storage_params
        params[:storage]
      end

      def add_on_purchases_params
        params[:add_on_purchases]
      end

      def sync_base_product
        return if base_product_params.blank?

        return if namespace.update(gitlab_subscription_attributes: base_product_params)

        errors << namespace.errors.full_messages
      end

      def sync_storage
        return if storage_params.blank?

        return if namespace.reset.update(storage_params)

        errors << namespace.errors.full_messages
      end

      def sync_compute_minutes
        return if compute_minutes_params.blank?

        result = SyncComputeMinutesService.new(namespace: namespace.reset, params: compute_minutes_params).execute
        return if result.success?

        errors << result.message
      end

      def sync_add_on_purchases
        return if add_on_purchases_params.blank?

        result = ::GitlabSubscriptions::AddOnPurchases::GitlabCom::ProvisionService.new(
          namespace.reset,
          add_on_purchases_params
        ).execute
        return if result.success?

        errors << result.message
      end
    end
  end
end
