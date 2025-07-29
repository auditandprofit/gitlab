# frozen_string_literal: true

module Geo
  class JobArtifactReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Ci::JobArtifact
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|CI Job Artifact')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|CI Job Artifacts')
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
