# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillLicensesOutsideSpdxCatalogue
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_licenses_outside_spdx_catalogue
          scope_to ->(relation) do
            relation.where(software_license_spdx_identifier: nil, custom_software_license_id: nil)
                    .where.not(software_license_id: nil)
          end
        end

        class SoftwareLicensePolicy < ::ApplicationRecord
          self.table_name = 'software_license_policies'

          belongs_to :software_license, -> { readonly }
        end

        class SoftwareLicense < ::ApplicationRecord
          self.table_name = 'software_licenses'
        end

        class CustomSoftwareLicense < ::ApplicationRecord
          self.table_name = 'custom_software_licenses'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            SoftwareLicensePolicy.id_in(sub_batch).includes(:software_license).find_each do |software_license_policy|
              software_license_name = software_license_policy.software_license.name

              custom_software_license = find_or_create_custom_software_license(software_license_name,
                software_license_policy.project_id)

              software_license_policy.update!(custom_software_license_id: custom_software_license.id)
            end
          end
        end

        def find_or_create_custom_software_license(name, project_id)
          params = { name: name, project_id: project_id }
          CustomSoftwareLicense.upsert(params, unique_by: [:project_id, :name])
          CustomSoftwareLicense.find_by(params)
        end
      end
    end
  end
end
