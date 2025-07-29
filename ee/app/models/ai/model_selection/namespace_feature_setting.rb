# frozen_string_literal: true

module Ai
  module ModelSelection
    class NamespaceFeatureSetting < ApplicationRecord
      include ::Ai::ModelSelection::FeaturesConfigurable
      include CascadingNamespaceSettingAttribute

      self.table_name = "ai_namespace_feature_settings"

      belongs_to :namespace, class_name: '::Group', inverse_of: :ai_feature_settings

      validates :feature, uniqueness: { scope: :namespace_id }

      validate :validate_root_namespace

      scope :for_namespace, ->(namespace_id) { where(namespace_id: namespace_id) }
      scope :non_default, -> { where.not(offered_model_ref: [nil, ""]) }

      def self.find_or_initialize_by_feature(namespace, feature)
        return unless namespace.present? && ::Feature.enabled?(:ai_model_switching, namespace)
        return unless namespace.root?

        feature_name = get_feature_name(feature)
        find_or_initialize_by(namespace_id: namespace.id, feature: feature_name)
      end

      def self.any_non_default_for_duo_chat?(namespace_id)
        for_namespace(namespace_id).non_default.where(feature: DUO_CHAT_FEATURES).exists?
      end

      def self.with_non_default_code_completions(namespace_ids)
        for_namespace(namespace_ids)
          .non_default
          .where(feature: :code_completions)
      end

      def model_selection_scope
        namespace
      end

      def set_to_gitlab_default?
        offered_model_ref.blank?
      end

      private

      def validate_root_namespace
        return if namespace&.root?

        errors.add(:namespace,
          'Model selection is only available for top-level namespaces.')
      end
    end
  end
end
