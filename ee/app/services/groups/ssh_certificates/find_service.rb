# frozen_string_literal: true

module Groups
  module SshCertificates
    class FindService
      def initialize(ca_fingerprint, user_identifier)
        @ca_fingerprint = ca_fingerprint
        @user_identifier = user_identifier
      end

      def execute
        certificate = ::Groups::SshCertificate.find_by_fingerprint(ca_fingerprint)
        return error('Certificate Not Found', :not_found) unless certificate

        group = certificate.group
        return error('Feature is not available', :forbidden) unless group.licensed_feature_available?(:ssh_certificates)

        user = ::User.find_by_login(user_identifier)
        user = group.all_group_members.non_invite.with_user(user).first ? user : nil

        return error('User Not Found', :not_found) unless user
        return error('Not an Enterprise User of the group', :forbidden) unless user.enterprise_user_of_group?(group)

        ServiceResponse.success(payload: { user: user, group: group })
      end

      private

      attr_reader :ca_fingerprint, :user_identifier

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end
