# frozen_string_literal: true

module Search
  class AuthorizationContext
    include ::Search::Elastic::Concerns::AuthorizationUtils

    def initialize(current_user)
      @current_user = current_user
    end

    def get_traversal_ids_for_group(group_id)
      ::Group.find(group_id).elastic_namespace_ancestry
    end

    # Supported options:
    # search_level
    # features
    # min_access_level
    # group_ids
    # project_ids
    def get_traversal_ids_for_user(options)
      traversal_ids_for_user(current_user, options)
    end

    # Supported options:
    # search_level
    # group_ids
    def get_project_ids_for_user(options)
      project_ids_for_user(current_user, options)
    end

    private

    attr_reader :current_user
  end
end
