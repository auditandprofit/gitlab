# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module MigrateRemainingSoftwareLicenseWithoutSpdxIdentifierToCustomLicenses
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :migrate_remaining_software_license_without_spdx_identifier_to_custom_licenses
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.exec_update(update_sql(sub_batch))
          end
        end

        def update_sql(sub_batch)
          <<~SQL
              INSERT INTO custom_software_licenses (name, project_id)
              SELECT
                name,
                project_id
            FROM
                software_license_policies
                INNER JOIN software_licenses ON (software_licenses.id = software_license_policies.software_license_id)
            WHERE
                software_licenses.spdx_identifier IS NULL
                AND software_license_policies.id IN (#{sub_batch.select(:id).to_sql})
            ON CONFLICT DO NOTHING
          SQL
        end
      end
    end
  end
end
