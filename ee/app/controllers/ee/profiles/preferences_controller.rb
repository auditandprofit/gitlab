# frozen_string_literal: true

module EE::Profiles::PreferencesController
  extend ::Gitlab::Utils::Override

  override :preferences_param_names
  def preferences_param_names
    super + preferences_param_names_ee
  end

  def preferences_param_names_ee
    params_ee = []
    params_ee.push({ user_preference_attributes: [:default_duo_add_on_assignment_id] }) if can_assign_default_duo_group?
    params_ee.push(:group_view) if License.feature_available?(:security_dashboard)
    params_ee.push(:enabled_zoekt) if user.has_exact_code_search?

    params_ee
  end

  def can_assign_default_duo_group?
    return false unless ::Feature.enabled?(:ai_model_switching, user)

    return false unless ::Gitlab::CurrentSettings.current_application_settings.duo_features_enabled

    true
  end
end
