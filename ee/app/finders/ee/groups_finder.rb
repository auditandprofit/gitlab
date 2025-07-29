# frozen_string_literal: true

module EE
  module GroupsFinder
    include Gitlab::Auth::Saml::SsoSessionFilterable
    extend ::Gitlab::Utils::Override

    private

    override :filter_groups
    def filter_groups(groups)
      groups = super(groups)
      groups = by_saml_sso_session(groups)
      by_repository_storage(groups)
    end

    def by_saml_sso_session(groups)
      filter_by_saml_sso_session(groups, :filter_expired_saml_session_groups)
    end

    def by_repository_storage(groups)
      return groups if params[:repository_storage].blank?

      groups.by_repository_storage(params[:repository_storage])
    end
  end
end
