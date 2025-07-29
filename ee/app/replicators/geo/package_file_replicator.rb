# frozen_string_literal: true

module Geo
  class PackageFileReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Packages::PackageFile
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Package File')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Package Files')
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
