# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillSoftwareLicenseSpdxIdentifierForSoftwareLicensePolicies
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_software_license_spdx_identifier_for_software_license_policies

          scope_to ->(relation) do
            relation.where(software_license_spdx_identifier: nil).where.not(software_license_id: nil)
          end
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
            SET software_license_spdx_identifier = software_licenses.spdx_identifier
            FROM software_licenses
            WHERE software_license_policies.software_license_id = software_licenses.id
            AND software_license_policies.id IN (#{sub_batch.select(:id).to_sql})
          SQL
        end
      end
    end
  end
end
