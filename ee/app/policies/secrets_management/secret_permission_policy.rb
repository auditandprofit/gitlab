# frozen_string_literal: true

module SecretsManagement
  class SecretPermissionPolicy < BasePolicy
    delegate { @subject.project }
  end
end
