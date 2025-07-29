# frozen_string_literal: true

module EE
  module IssuePolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    override :epics_license_available?
    def epics_license_available?
      subject_container.licensed_feature_available?(:epics) || super
    end

    override :project_work_item_epics_available?
    def project_work_item_epics_available?
      (subject_container.project_epics_enabled? && epics_license_available?) || super
    end

    prepended do
      condition(:relations_for_non_members_available) do
        scope = group_issue? ? subject_container : subject_container.group

        ::Feature.enabled?(:epic_relations_for_non_members, scope)
      end

      condition(:member_or_support_bot) do
        (is_project_member? && can?(:read_issue)) || (support_bot? && service_desk_enabled?)
      end

      rule { can_be_promoted_to_epic }.policy do
        enable :promote_to_epic
      end

      rule { relations_for_non_members_available & ~member_or_support_bot }.policy do
        prevent :admin_issue_relation
      end

      # summarize comments is enabled at namespace(project or group) level, however if issue is confidential
      # and user(e.g. guest cannot read issue) we do not allow summarize comments
      rule { ~can?(:read_issue) }.policy do
        prevent :summarize_comments
      end

      # This rule is already defined in FOSS IssuePolicy, but EE::IssuePolicy may be adding EE specific abilities
      # that would be captured here, e.g. `summarize_comments`, `promote_to_epic`, etc
      rule { ~work_item_type_available }.policy do
        prevent(*::IssuePolicy.ability_map.map.keys)
      end
    end
  end
end
