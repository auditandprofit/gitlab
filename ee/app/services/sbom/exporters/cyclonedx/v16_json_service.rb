# frozen_string_literal: true

module Sbom
  module Exporters
    module Cyclonedx
      # This exporter serializes the dependency list into a CycloneDX SBoM.
      # It handles spec version 1.6 in JSON format.
      # https://cyclonedx.org/docs/1.6/json/
      class V16JsonService
        include WriteBlob

        VENDOR = 'GitLab'

        def initialize(export, sbom_occurrences)
          @export = export
          @sbom_occurrences = sbom_occurrences
        end

        attr_reader :export

        delegate :project, to: :export

        def generate(&block)
          write_json_blob(bom, &block)
        end

        private

        def bom
          bom_header.merge({ 'components' => components })
        end

        def components
          sbom_occurrences.map { |occurrence| component(occurrence) }
        end

        def sbom_occurrences
          [].tap do |arr|
            @sbom_occurrences.each_batch do |batch|
              arr.concat(batch.with_component.with_version.to_a)
            end
          end
        end

        def component(occurrence)
          purl = occurrence.purl&.to_s

          component = {
            'name' => occurrence.name,
            'version' => occurrence.version,
            'type' => 'library',
            'bom-ref' => purl || serial,
            'licenses' => licenses(occurrence)
          }

          component['purl'] = purl if purl.present?
          component
        end

        def licenses(occurrence)
          occurrence.licenses.filter_map do |license|
            if license['spdx_identifier'] == Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE[:spdx_identifier]
              next
            end

            {
              'license' => license_data(license)
            }
          end
        end

        def license_data(license)
          id = license['spdx_identifier']

          return { 'id' => id } if id.present?

          license.slice('name')
        end

        def bom_header
          {
            'bomFormat' => 'CycloneDX',
            'specVersion' => '1.6',
            'serialNumber' => serial,
            'version' => 1,
            'metadata' => bom_metadata
          }
        end

        def serial
          Gitlab::UUID.urn
        end

        def bom_metadata
          {
            'timestamp' => timestamp,
            'tools' => [gitlab_tool],
            'manufacturer' => gitlab_manufacturer,
            'component' => metadata_component
          }
        end

        def gitlab_tool
          {
            'vendor' => VENDOR,
            'name' => 'GitLab dependency list export',
            'version' => Gitlab::VERSION
          }
        end

        def gitlab_manufacturer
          {
            'name' => VENDOR,
            'url' => ['https://about.gitlab.com/'],
            'contact' => [{
              'name' => 'GitLab Support',
              'email' => 'support@gitlab.com'
            }]
          }
        end

        def metadata_component
          {
            'type' => 'application',
            'name' => project.name,
            'externalReferences' => [project_reference]
          }
        end

        def project_reference
          {
            'type' => 'vcs',
            'url' => project.http_url_to_repo
          }
        end

        def timestamp
          Time.zone.now
        end
      end
    end
  end
end
