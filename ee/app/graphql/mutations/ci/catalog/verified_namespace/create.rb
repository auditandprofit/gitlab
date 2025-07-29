# frozen_string_literal: true

module Mutations
  module Ci
    module Catalog
      module VerifiedNamespace
        class Create < Mutations::BaseMutation
          graphql_name 'VerifiedNamespaceCreate'

          description 'Create a verified namespace and mark all child catalog resources ' \
            'with the passed verification level info.'

          include ::GitlabSubscriptions::SubscriptionHelper

          authorize :admin_all_resources

          include Mutations::ResolvesNamespace

          argument :namespace_path,
            GraphQL::Types::ID,
            required: true,
            description: 'Root namespace path.'

          argument :verification_level,
            Types::Ci::Catalog::Resources::VerificationLevelEnum,
            required: true,
            description: 'Verification level for a root namespace.'

          def resolve(namespace_path:, verification_level:)
            if self_managed_or_dedicated? && verification_level != 'verified_creator_self_managed'
              { errors: ["Cannot use #{verification_level} on a non-Gitlab.com instance." \
                "Use `VERIFIED_CREATOR_SELF_MANAGED`."] }
            elsif allowed_verification?(verification_level)
              namespace = authorized_find!(namespace_path: namespace_path)
              result = ::Ci::Catalog::VerifyNamespaceService.new(namespace, verification_level).execute

              errors = result.success? ? [] : [result.message]
              {
                errors: errors
              }
            end
          end

          private

          def self_managed_or_dedicated?
            !gitlab_com_subscription?
          end

          def allowed_verification?(verification_level)
            (self_managed_or_dedicated? && verification_level == 'verified_creator_self_managed') ||
              gitlab_com_subscription?
          end

          def find_object(namespace_path:)
            resolve_namespace(full_path: namespace_path)
          end
        end
      end
    end
  end
end
