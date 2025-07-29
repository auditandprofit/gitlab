# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixProjectSettingsHasVulnerabilities
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :fix_has_vulnerabilities
        end

        class ProjectSettings < ApplicationRecord; end

        override :perform
        def perform
          distinct_each_batch do |sub_batch|
            project_ids = sub_batch.pluck(:project_id)

            ProjectSettings.where(project_id: project_ids)
                           .where('has_vulnerabilities IS NOT true')
                           .update_all(has_vulnerabilities: true)
          end
        end
      end
    end
  end
end
