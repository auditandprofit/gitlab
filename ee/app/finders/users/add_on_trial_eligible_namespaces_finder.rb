# frozen_string_literal: true

module Users
  class AddOnTrialEligibleNamespacesFinder
    def initialize(user, add_on:)
      @user = user
      @add_on = add_on
    end

    def execute
      return Namespace.none unless add_on_exists?

      items = user.owned_groups.ordered_by_name
      by_add_on(items)
    end

    private

    attr_reader :user, :add_on

    def by_add_on(items)
      case add_on
      when :duo
        items.in_specific_plans(GitlabSubscriptions::DuoPro::ELIGIBLE_PLAN)
             .not_duo_pro_or_no_add_on
             .not_duo_enterprise_or_no_add_on
      when :duo_enterprise
        items.in_specific_plans(GitlabSubscriptions::DuoEnterprise::ELIGIBLE_PLANS).not_duo_enterprise_or_no_add_on
      end
    end

    def add_on_exists?
      case add_on
      when :duo
        GitlabSubscriptions::AddOn.code_suggestions.or(GitlabSubscriptions::AddOn.duo_enterprise).exists?
      when :duo_enterprise
        GitlabSubscriptions::AddOn.duo_enterprise.exists?
      else
        raise ArgumentError, "Unknown add_on: #{add_on}"
      end
    end
  end
end
