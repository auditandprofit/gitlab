# frozen_string_literal: true

module Ai
  class SettingPolicy < BasePolicy
    condition(:allowed_to_read_self_hosted_models_settings) do
      @user&.can?(:manage_self_hosted_models_settings)
    end

    condition(:allowed_to_read_duo_core_settings) do
      @user&.can?(:manage_duo_core_settings)
    end

    rule { allowed_to_read_self_hosted_models_settings }.policy do
      enable :read_self_hosted_models_settings
    end

    rule { allowed_to_read_duo_core_settings }.policy do
      enable :read_duo_core_settings
    end
  end
end
