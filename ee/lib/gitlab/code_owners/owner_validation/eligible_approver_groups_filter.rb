# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class EligibleApproverGroupsFilter
        include ::Gitlab::Utils::StrongMemoize

        def initialize(project, groups:, group_names:)
          @project = project
          @input_groups = groups
          @input_group_names = group_names
        end

        def error_message
          :group_without_eligible_approvers
        end

        def output_groups
          preload_associations

          input_groups.select { |group| any_approvers?(group) }
        end
        strong_memoize_attr :output_groups

        def valid_group_names
          output_groups.map(&:full_path)
        end
        strong_memoize_attr :valid_group_names

        def invalid_group_names
          input_group_names - valid_group_names
        end
        strong_memoize_attr :invalid_group_names

        def valid_entry?(references)
          !references.names.intersect?(invalid_group_names)
        end

        private

        attr_reader :project, :input_groups, :input_group_names

        def preload_associations
          ActiveRecord::Associations::Preloader.new(records: input_groups, associations: [users: :namespace_bans]).call
          user_ids = input_groups.flat_map(&:user_ids).uniq
          project.team.max_member_access_for_user_ids(user_ids)
        end

        def any_approvers?(group)
          group.users.any? { |user| user.can?(:update_merge_request, project) }
        end
      end
    end
  end
end
