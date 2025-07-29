# frozen_string_literal: true

module EE
  module SearchService
    extend ::Gitlab::Utils::Override

    # This is a proper method instead of a `delegate` in order to
    # avoid adding unnecessary methods to Search::SnippetService
    def use_elasticsearch?
      search_service.use_elasticsearch?
    end

    def show_epics?
      search_service.allowed_scopes.include?('epics')
    end

    def show_elasticsearch_tabs?
      ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: search_service.elasticsearchable_scope)
    end

    override :search_type
    def search_type
      search_service.search_type
    end

    def use_zoekt?
      search_service.try(:use_zoekt?)
    end

    override :global_search_enabled_for_scope?
    def global_search_enabled_for_scope?
      case params[:scope]
      when 'blobs'
        ::Gitlab::CurrentSettings.global_search_code_enabled?
      when 'commits'
        ::Gitlab::CurrentSettings.global_search_commits_enabled?
      when 'epics'
        ::Gitlab::CurrentSettings.global_search_epics_enabled?
      when 'wiki_blobs'
        ::Gitlab::CurrentSettings.global_search_wiki_enabled?
      else
        super
      end
    end

    override :search_type_errors
    def search_type_errors
      errors = []

      case params[:search_type]
      when 'advanced'
        errors << 'Elasticsearch is not available' unless use_elasticsearch?
      when 'zoekt'
        errors << 'Zoekt is not available' unless use_zoekt?
        errors << 'Zoekt can only be used for blobs' unless scope == 'blobs'
      end

      return if errors.empty?

      errors.join(', ')
    end
  end
end
