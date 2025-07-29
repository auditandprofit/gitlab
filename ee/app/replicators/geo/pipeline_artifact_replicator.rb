# frozen_string_literal: true

module Geo
  class PipelineArtifactReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Ci::PipelineArtifact
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Pipeline Artifact')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Pipeline Artifacts')
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
