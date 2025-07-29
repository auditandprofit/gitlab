# frozen_string_literal: true

module GitlabSubscriptions
  module DuoCore
    DELAY_TODO_NOTIFICATION = 7.days

    def self.any_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_core
      ).execute.any?
    end

    def self.available?(user, namespace)
      if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
        user.can?(:access_duo_core_features, namespace)
      else
        user.can?(:access_duo_core_features)
      end
    end
  end
end
