# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      # This class is responsible for updating workspaces config_version and force_include_all_resources.
      module UpdateWorkspacesConfigVersion3
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        VERSION_2 = 2
        VERSION_3 = 3
        STATE_TERMINATED = 'Terminated'

        prepended do
          operation_name :update
          scope_to ->(relation) {
            relation.where(config_version: VERSION_2)
                    .where.not(actual_state: STATE_TERMINATED)
          }
          feature_category :workspaces
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.update_all(config_version: VERSION_3,
              force_include_all_resources: true)
          end
        end
      end
    end
  end
end
