# frozen_string_literal: true

module CloudConnector
  class BaseAvailableServiceData
    attr_reader :name, :cut_off_date, :add_on_names

    def initialize(name, cut_off_date, add_on_names)
      @name = name
      @cut_off_date = cut_off_date
      @add_on_names = map_duo_pro(add_on_names)
    end

    # Returns CloudConnector access JWT token.
    #
    # For Gitlab.com it will self-issue a token with scopes based on provided resource:
    # - For provided user, it will self-issue a token with scopes based on user assigment permissions
    # - For provided namespace, it will self-issue a token with scopes based on add-on purchased permissions
    #
    # For SM, it will return :CloudConnector::ServiceAccessToken instance token
    #
    # resource - User or Namespace
    # extra_claims: - extra_claims can be included for self-issued access_token on gitlab.com
    def access_token(_resource = nil, **)
      raise 'Not implemented'
    end

    private

    # TODO: We shold remove this when https://gitlab.com/gitlab-org/gitlab/-/issues/458745 is done
    def map_duo_pro(add_on_names)
      add_on_names&.map { |add_on| add_on == 'duo_pro' ? 'code_suggestions' : add_on } || []
    end

    def add_on_purchases_assigned_to(user)
      add_on_purchases.assigned_to_user(user)
    end
  end
end
