# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module DisableAllowRunnerRegistrationOnNamespaceSettingsForGitlabCom
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :disable_runner_registration_tokens_on_top_level_groups
          scope_to ->(relation) { relation.where(parent_id: nil).where(type: 'Group') }
          feature_category :fleet_visibility
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.exec_query(<<~SQL)
              -- Disable runner registration tokens for all top-level groups
              INSERT INTO namespace_settings (namespace_id, allow_runner_registration_token, created_at, updated_at)
                (#{sub_batch.select('id, FALSE, NOW(), NOW()').to_sql})
              ON CONFLICT (namespace_id)
                DO UPDATE SET
                  allow_runner_registration_token = FALSE;
            SQL
          end
        end
      end
    end
  end
end
