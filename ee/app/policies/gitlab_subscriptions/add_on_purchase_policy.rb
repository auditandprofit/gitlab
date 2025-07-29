# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnPurchasePolicy < ::BasePolicy
    condition(:namespace_owner) do
      can?(:owner_access, @subject.namespace)
    end

    rule { admin | namespace_owner }.policy do
      enable :admin_add_on_purchase
    end
  end
end
