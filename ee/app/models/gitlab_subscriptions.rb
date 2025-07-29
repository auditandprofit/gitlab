# frozen_string_literal: true

module GitlabSubscriptions
  def self.table_name_prefix
    'subscription_'
  end

  def self.find_eligible_namespace(user:, namespace_id:, plan_id: nil)
    return unless namespace_id.present?

    eligible_namespaces = GitlabSubscriptions::PurchaseEligibleNamespacesFinder.new(
      user: user,
      namespace_id: namespace_id,
      plan_id: plan_id
    ).execute

    eligible_namespaces.first
  end
end
