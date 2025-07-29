# frozen_string_literal: true

module EE
  module Gitlab
    module Scim
      # rubocop:disable Gitlab/EeOnlyClass -- All existing instance SCIM code
      # currently lives under ee/ and making it compliant requires a larger
      # refactor to be addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/520129.
      class GroupSyncDeletionService
        attr_reader :scim_group_uid

        def initialize(scim_group_uid:)
          @scim_group_uid = scim_group_uid
        end

        def execute
          clear_scim_group_uid_from_links

          schedule_membership_cleanup

          ServiceResponse.success
        rescue ActiveRecord::ActiveRecordError => e
          ServiceResponse.error(message: e.message)
        end

        private

        def clear_scim_group_uid_from_links
          SamlGroupLink.by_scim_group_uid(scim_group_uid).update_all(scim_group_uid: nil)
        end

        def schedule_membership_cleanup
          ::Authn::CleanupScimGroupMembershipsWorker.perform_async(scim_group_uid)
        end
      end
      # rubocop:enable Gitlab/EeOnlyClass
    end
  end
end
