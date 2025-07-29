# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillSoftwareLicensePolicies
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize

        prepended do
          operation_name :migrate_licenses_outside_spdx_to_custom_license
          scope_to ->(relation) do
            relation.where(software_license_spdx_identifier: nil)
              .where(custom_software_license_id: nil)
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
              spdx_identifier = licenses_map[software_license_name]

              if spdx_identifier.present?
                software_license_policy.update!(software_license_spdx_identifier: spdx_identifier)
              else
                custom_software_license = find_or_create_custom_software_license(software_license_name,
                  software_license_policy.project_id)

                software_license_policy.update!(custom_software_license_id: custom_software_license.id)
              end
            end
          end
        end

        private

        def find_or_create_custom_software_license(name, project_id)
          params = { name: name, project_id: project_id }
          CustomSoftwareLicense.upsert(params, unique_by: [:project_id, :name])
          CustomSoftwareLicense.find_by(params)
        end

        def licenses_map
          catalog_licenses = ::Gitlab::SPDX::Catalogue.latest_active_licenses

          catalog_licenses.each_with_object({}) do |license, map|
            map[license.name] = license.id
          end
        end
        strong_memoize_attr :licenses_map
      end
    end
  end
end
