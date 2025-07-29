# frozen_string_literal: true

# Finder for retrieving authorized groups to use for search
# This finder returns all groups that a user has authorization to because:
# 1. They are direct members of the group with either:
#   - the minimum access level required
#   - a custom role that allows the ability requested
# 2. They are direct members of a group that is invited to the group with either:
#   - the minimum access level required
#   - a custom role that allows the ability requested
#
# Min access level can be changed by sending `features` option in params. Min access defaults to GUEST
# This finder does not take into account a group's sub-groups, descendants, or ancestors
module Search
  class GroupsFinder
    include Gitlab::Utils::StrongMemoize
    include Search::Concerns::FeatureCustomAbilityMap

    DEFAULT_MIN_ACCESS_LEVEL = ::Gitlab::Access::GUEST

    # user - The currently logged-in user, if any.
    # params
    #  * features (optional, default GUEST) - Sets minimum access level required to access project features.
    #    Cannot be provided with min_access_level
    #  * min_access_level (optional, default GUEST) - Sets minimum access level.
    #    Cannot be provided with features
    def initialize(user:, params: {})
      @user = user
      @params = params
    end

    def execute
      return Group.none unless user

      validate_arguments!

      Group.unscoped do
        Group.from_union([
          direct_groups_with_min_access_level,
          direct_groups_with_custom_role_abilities,
          linked_groups_with_min_access_level
        ].compact)
      end
    end

    private

    attr_reader :user, :params

    def validate_arguments!
      return unless params[:min_access_level].present? && params[:features].present?

      raise ArgumentError, 'only min_access_level or features can be provided, not both'
    end

    def direct_groups_with_min_access_level
      Group.id_in(direct_groups.with_at_least_access_level(min_access_level).select(:source_id))
    end

    def direct_groups_with_custom_role_abilities
      return Group.none if target_abilities.blank?

      groups = Group.id_in(direct_groups.select(:source_id))
      actual_abilities = ::Authz::Group.new(user, scope: groups).permitted
      allowed_group_ids = groups.filter_map do |group|
        group.id if (actual_abilities[group.id] || []).intersection(target_abilities).any?
      end

      return Group.none if allowed_group_ids.blank?

      Group.id_in(allowed_group_ids)
    end

    def direct_groups
      user.group_members.active
    end

    def linked_groups_with_min_access_level
      group_links = GroupGroupLink.for_shared_with_groups(direct_groups.select(:source_id)).not_expired
      group_links = group_links.with_at_least_group_access(min_access_level)

      Group.id_in(group_links.select(:shared_group_id))
    end

    def target_abilities
      features = params[:features]
      return [] if features.blank?

      features.map { |feature| FEATURE_TO_ABILITY_MAP[feature.to_sym] }
    end
    strong_memoize_attr :target_abilities

    def min_access_level
      features = params[:features]
      return params.fetch(:min_access_level, DEFAULT_MIN_ACCESS_LEVEL) if features.blank?

      features.map do |feature|
        ProjectFeature.required_minimum_access_level_for_private_project(feature)
      end.min
    end
    strong_memoize_attr :min_access_level
  end
end
