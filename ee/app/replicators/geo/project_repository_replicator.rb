# frozen_string_literal: true

module Geo
  class ProjectRepositoryReplicator < Gitlab::Geo::Replicator
    include ::Geo::RepositoryReplicatorStrategy

    def self.model
      ::Project
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Project Repository')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Project Repositories')
    end

    def before_housekeeping
      return unless ::Gitlab::Geo.secondary?

      create_object_pool_on_secondary if create_object_pool_on_secondary?
    end

    def repository
      model_record.repository
    end

    private

    def pool_repository
      model_record.pool_repository
    end

    def create_object_pool_on_secondary
      Geo::CreateObjectPoolService.new(pool_repository).execute
    end

    def create_object_pool_on_secondary?
      return unless model_record.object_pool_missing?
      return unless pool_repository.source_project_repository.exists?

      true
    end
  end
end
