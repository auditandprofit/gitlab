# frozen_string_literal: true

module EE
  module API
    module Entities
      module Group
        extend ActiveSupport::Concern

        prepended do
          expose :ldap_cn, :ldap_access
          expose :ldap_group_links,
            using: EE::API::Entities::LdapGroupLink,
            if: ->(group, options) { group.ldap_group_links.any? }

          expose :saml_group_links,
            using: EE::API::Entities::SamlGroupLink,
            if: ->(group, options) { group.saml_group_links.any? }

          expose :checked_file_template_project_id,
            as: :file_template_project_id,
            if: ->(group, options) {
              group.licensed_feature_available?(:custom_file_templates_for_namespace) &&
                Ability.allowed?(options[:current_user], :read_project, group.checked_file_template_project)
            }

          expose :wiki_access_level do |group|
            group.group_feature.string_access_level(:wiki)
          end

          expose :repository_storage,
            if: ->(group, options) {
              group.licensed_feature_available?(:group_wikis) &&
                Ability.allowed?(options[:current_user], :change_repository_storage)
            } do |group|
            group.group_wiki_repository&.shard_name
          end

          expose :duo_core_features_enabled,
            if: ->(group, options) {
              group.licensed_duo_core_features_available? &&
                Ability.allowed?(options[:current_user], :admin_group, group)
            }, documentation: {
              desc: '[Experimental] Indicates whether GitLab Duo Core features are enabled for the group',
              type: 'boolean'
            }

          expose :duo_features_enabled,
            if: ->(group, options) {
              group.licensed_ai_features_available? &&
                Ability.allowed?(options[:current_user], :admin_group, group)
            }
          expose :lock_duo_features_enabled,
            if: ->(group, options) {
              group.licensed_ai_features_available? &&
                Ability.allowed?(options[:current_user], :admin_group, group)
            }
          expose :web_based_commit_signing_enabled,
            if: ->(group, options) {
              ::Gitlab::Saas.feature_available?(:repositories_web_based_commit_signing) &&
                Ability.allowed?(options[:current_user], :admin_group, group)
            }
        end
      end
    end
  end
end
