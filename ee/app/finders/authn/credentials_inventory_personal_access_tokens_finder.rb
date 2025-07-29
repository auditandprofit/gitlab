# frozen_string_literal: true

module Authn
  class CredentialsInventoryPersonalAccessTokensFinder < ::PersonalAccessTokensFinder
    extend ::Gitlab::Utils::Override

    # Based on PersonalAccessToken.simple_sorts
    # Static hash sorting hashes are needed since the existing lambdas
    # can't be used for sorting in the optimization
    SORT_ORDER_KEYS_FOR_GROUP_CREDENTIALS_INVENTORY = {
      # Expires_at
      'expires_asc' => { expires_at: :asc, id: :desc },
      'expires_at_asc_id_desc' => { expires_at: :asc, id: :desc },
      'expires_desc' => { expires_at: :desc, id: :desc },

      # Last_used
      'last_used_asc' => { last_used_at: :asc, id: :desc },
      'last_used_desc' => { last_used_at: :desc, id: :desc },

      # Created_at
      'created_asc' => { created_at: :asc, id: :desc },
      'created_at_asc' => { created_at: :asc, id: :desc },
      'created_date' => { created_at: :desc, id: :asc },
      'created_desc' => { created_at: :desc, id: :asc },
      'created_at_desc' => { created_at: :desc, id: :asc },

      # IDs
      'id_asc' => { id: :asc },
      'id_desc' => { id: :desc },

      # Name
      'name_asc' => { name: :asc, id: :desc },
      'name_desc' => { name: :desc, id: :asc },

      # Updated_at
      'updated_asc' => { updated_at: :asc, id: :desc },
      'updated_at_asc' => { updated_at: :asc, id: :desc },
      'updated_desc' => { updated_at: :desc, id: :asc },
      'updated_at_desc' => { updated_at: :desc, id: :asc }
    }.freeze

    override :execute
    def execute
      if ::Feature.enabled?(:credentials_inventory_pat_finder, top_level_group || :instance)
        optimized_execute_for_credentials_inventory
      else
        super
      end
    end

    # Executes an optimized query for efficiently retrieving the PATs of enterpise users by
    # using recursive queries and composite indexes for sorting
    #
    # @return [ActiveRecord::Relation] a relation of personal access tokens.
    # @note Requires a limit to be applied after execution. Gitlab's current Kaminari default is 20.
    # @reference See https://docs.gitlab.com/development/database/efficient_in_operator_queries
    def optimized_execute_for_credentials_inventory
      # rubocop:disable CodeReuse/ActiveRecord -- where clauses needed for AREL optimization
      pat_table = PersonalAccessToken.arel_table
      base_scope = PersonalAccessToken.where(impersonation: false) # impersonation needs to match array_mapping_scope

      scope = filtered_pats_for_group_credentials_inventory_finder(base_scope)
                .order(sort_order_for_group_credentials_inventory_finder)

      array_scope = get_credentials_inventory_user_ids

      array_mapping_scope = ->(id_expression) {
        base_mapping_scope_query = PersonalAccessToken
          .where(pat_table[:user_id].eq(id_expression))
          .where(pat_table[:impersonation].eq(false))

        filtered_pats_for_group_credentials_inventory_finder(base_mapping_scope_query)
      }

      # See https://docs.gitlab.com/development/database/pagination_performance_guidelines/#tie-breaker-column
      finder_query = if sort_order == 'id_asc' || sort_order == 'id_desc'
                       ->(id_expression) {
                         PersonalAccessToken.where(pat_table[:id].eq(id_expression))
                       }
                     else
                       ->(_created_at_expression, id_expression) {
                         PersonalAccessToken.where(pat_table[:id].eq(id_expression))
                       }
                     end

      # rubocop:enable CodeReuse/ActiveRecord
      Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder.new(
        scope: scope,
        array_scope: array_scope,
        array_mapping_scope: array_mapping_scope,
        finder_query: finder_query
      ).execute
    end

    private

    def sort_order
      params[:sort]
    end

    def sort_order_for_group_credentials_inventory_finder
      SORT_ORDER_KEYS_FOR_GROUP_CREDENTIALS_INVENTORY[sort_order] || { expires_at: :asc, id: :desc }
    end

    def filtered_pats_for_group_credentials_inventory_finder(base_query)
      tokens = by_state(base_query)
      tokens = by_revoked_state(tokens)

      tokens = by_created_before(tokens)
      tokens = by_created_after(tokens)
      tokens = by_expires_before(tokens)
      tokens = by_expires_after(tokens)
      tokens = by_last_used_before(tokens)
      tokens = by_last_used_after(tokens)
      tokens = by_owner_type(tokens)

      by_search(tokens)
    end

    def users
      params[:users]
    end

    def top_level_group
      params[:group]
    end

    def get_credentials_inventory_user_ids
      if enterprise_users?
        top_level_group.enterprise_user_details.or(top_level_group.provisioned_user_details).select(:user_id)
      else
        users.select(:id)
      end
    end

    def enterprise_users?
      top_level_group.present?
    end
  end
end
