# frozen_string_literal: true

# See https://docs.gitlab.com/ee/development/database/batched_background_migrations.html
# for more information on how to use batched background migrations

# Update below commented lines with appropriate values.

module EE
  module Gitlab
    module BackgroundMigration
      module UpdateSoftwareLicensePoliciesWithCustomLicenses
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :update_software_license_policies_with_custom_licenses
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.exec_update(update_sql(sub_batch))
          end
        end

        def update_sql(sub_batch)
          <<~SQL
              UPDATE software_license_policies
              SET custom_software_license_id = custom_software_licenses.id
            FROM
                custom_software_licenses
                JOIN software_licenses ON custom_software_licenses.name = software_licenses.name
            WHERE
                software_licenses.spdx_identifier IS NULL
                AND custom_software_licenses.project_id = software_license_policies.project_id
                AND software_licenses.id = software_license_policies.software_license_id
                AND software_license_policies.id IN (#{sub_batch.select(:id).to_sql})
          SQL
        end
      end
    end
  end
end
