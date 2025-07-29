# frozen_string_literal: true

module Geo
  class TerraformStateVersionReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def carrierwave_uploader
      model_record.file
    end

    def self.model
      ::Terraform::StateVersion
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Terraform State Version')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Terraform State Versions')
    end
  end
end
