# frozen_string_literal: true

module Gitlab
  module CodeOwners
    module OwnerValidation
      class AccessibleOwnersFilter
        include ::Gitlab::Utils::StrongMemoize

        def initialize(project, names:, emails:)
          @project = project
          @input_names = names
          @input_emails = emails
        end

        def error_message
          :inaccessible_owner
        end

        def output_groups
          GroupsLoader.new(project, names: input_names).groups
        end
        strong_memoize_attr :output_groups

        def output_users
          UsersLoader.new(project, emails: input_emails, names: group_filtered_input_names).members
        end
        strong_memoize_attr :output_users

        def valid_group_names
          output_groups.map(&:full_path)
        end
        strong_memoize_attr :valid_group_names

        def valid_usernames
          group_filtered_input_names - invalid_names
        end
        strong_memoize_attr :valid_usernames

        def invalid_names
          group_filtered_input_names - output_users.map(&:username)
        end
        strong_memoize_attr :invalid_names

        def invalid_emails
          input_emails - output_users.flat_map(&:verified_emails)
        end
        strong_memoize_attr :invalid_emails

        def valid_emails
          input_emails - invalid_emails
        end
        strong_memoize_attr :valid_emails

        def valid_entry?(references)
          valid_references?(references.names, invalid_names) &&
            valid_references?(references.emails, invalid_emails)
        end

        private

        attr_reader :project, :input_names, :input_emails

        def group_filtered_input_names
          input_names - valid_group_names
        end
        strong_memoize_attr :group_filtered_input_names

        def valid_references?(references, invalid_references)
          !references.intersect?(invalid_references)
        end
      end
    end
  end
end
