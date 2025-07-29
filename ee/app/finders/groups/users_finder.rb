# frozen_string_literal: true

module Groups
  class UsersFinder < UsersFinder
    extend ::Gitlab::Utils::Override

    attr_accessor :group

    ALLOWED_FILTERS = [:include_saml_users, :include_service_accounts].freeze

    def initialize(current_user, group, params)
      @current_user = current_user
      @group = group.root_ancestor
      @params = params || {}

      raise_params_error unless at_least_one_param_true?
    end

    private

    override :base_scope
    def base_scope
      users = super
      relations = relations_to_join(users)

      return relations.first if relations.size == 1

      union = ::User.from_union(relations)
      union.order_id_desc
    end

    def relations_to_join(users)
      relations = []

      relations << saml_users(users)
      relations << service_accounts(users)

      relations.compact
    end

    def saml_users(users)
      saml_provider_id = group.saml_provider
      return unless params[:include_saml_users] && saml_provider_id

      users.with_saml_provider(saml_provider_id)
    end

    def service_accounts(users)
      return unless params[:include_service_accounts]

      users.service_account.with_provisioning_group(group)
    end

    def at_least_one_param_true?
      ALLOWED_FILTERS.any? { |param| params[param] }
    end

    def raise_params_error
      raise(ArgumentError, format(_("At least one of %{params} must be true"), params: ALLOWED_FILTERS.join(', ')))
    end
  end
end
