# frozen_string_literal: true

module EE
  module Search
    module GroupSettings
      extend ActiveSupport::Concern

      extend ::Gitlab::Utils::Override

      override :general_settings
      def general_settings
        settings = super

        if group.licensed_feature_available?(:group_project_templates)
          settings.push(
            { text: _('Custom project templates'),
              href: edit_group_path(group, anchor: 'js-custom-project-templates-settings') }
          )
        end

        if group.licensed_feature_available?(:custom_file_templates_for_namespace)
          settings.push(
            { text: _('Templates'), href: edit_group_path(group, anchor: 'js-templates') }
          )
        end

        if group.licensed_feature_available?(:group_level_merge_checks_setting)
          settings.push(
            { text: _('Merge requests'), href: edit_group_path(group, anchor: 'js-merge-requests-settings') }
          )
        end

        if group.licensed_feature_available?(:merge_request_approvers)
          settings.push(
            { text: _('Merge request approvals'),
              href: edit_group_path(group, anchor: 'js-merge-request-approval-settings') }
          )
        end

        if License.feature_available?(:pages_size_limit)
          settings.push(
            { text: _('Pages'), href: edit_group_path(group, anchor: 'js-pages-settings') }
          )
        end

        if ::Ai::AmazonQ.connected?
          settings.push(
            { text: _('Amazon Q'), href: edit_group_path(group, anchor: 'js-amazon-q-settings') }
          )
        end

        settings
      end

      override :repository_settings
      def repository_settings
        settings = super

        if group.licensed_feature_available?(:push_rules)
          settings.push(
            { text: _('Pre-defined push rules'), href: group_settings_repository_path(group, anchor: 'js-push-rules') }
          )
        end

        settings
      end

      override :ci_cd_settings
      def ci_cd_settings
        settings = super

        if group.licensed_feature_available?(:protected_environments)
          settings.push(
            { text: _('Protected environments'),
              href: group_settings_ci_cd_path(group, anchor: 'js-protected-environments-settings') }
          )
        end

        settings
      end
    end
  end
end
