# frozen_string_literal: true

module Geo
  class SnippetRepositoryReplicator < Gitlab::Geo::Replicator
    include ::Geo::RepositoryReplicatorStrategy

    def self.model
      ::SnippetRepository
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Snippet Repository')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Snippet Repositories')
    end

    override :housekeeping_enabled?
    def self.housekeeping_enabled?
      false
    end

    def repository
      model_record.repository
    end
  end
end
