# frozen_string_literal: true

module Ai
  module ModelSelection
    class UpdateService
      include Gitlab::InternalEventsTracking

      def initialize(feature_setting, user, params)
        @feature_setting = feature_setting
        @user = user
        @params = params
        @selection_scope = feature_setting.model_selection_scope
      end

      def execute
        unless Feature.enabled?(:ai_model_switching, selection_scope)
          return ServiceResponse.error(payload: nil,
            message: 'Contact your admin to enable the feature flag for AI Model Switching')
        end

        update_params = { offered_model_ref: params[:offered_model_ref] }

        fetch_model_definition = Ai::ModelSelection::FetchModelDefinitionsService
                                   .new(user, model_selection_scope: selection_scope)
                                   .execute

        return ServiceResponse.error(message: fetch_model_definition.message) if fetch_model_definition.error?

        update_params[:model_definitions] = fetch_model_definition.payload

        if feature_setting.update(update_params)
          record_audit_event
          track_update_event

          ServiceResponse.success(payload: feature_setting)
        else
          ServiceResponse.error(payload: feature_setting,
            message: feature_setting.errors.full_messages.join(", "))
        end
      end

      private

      attr_accessor :feature_setting, :user, :selection_scope, :params

      def record_audit_event
        model = params[:offered_model_ref]
        feature = feature_setting.feature
        scope_type = selection_scope.class.name
        scope_id = selection_scope.id

        audit_context = {
          name: 'model_selection_feature_changed',
          author: user,
          scope: selection_scope,
          target: selection_scope,
          message: "The LLM #{model} has been selected for the feature #{feature} of #{scope_type} with ID #{scope_id}",
          additional_details: {
            model_ref: model,
            feature: feature
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def track_update_event
        selection_scope_gid = selection_scope.to_global_id.to_s

        track_internal_event(
          'update_model_selection_feature',
          user: user,
          additional_properties: {
            label: params[:offered_model_ref],
            property: feature_setting.feature,
            selection_scope_gid: selection_scope_gid
          }
        )
      end
    end
  end
end
