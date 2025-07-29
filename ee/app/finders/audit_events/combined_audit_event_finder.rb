# frozen_string_literal: true

module AuditEvents
  # Finder for retrieving audit events across multiple models with unified pagination.
  #
  # This finder combines audit events from four different models:
  # - InstanceAuditEvent (instance-wide events)
  # - UserAuditEvent (user-specific events)
  # - ProjectAuditEvent (project-specific events)
  # - GroupAuditEvent (group-specific events)
  #
  # How it works:
  # 1. Builds individual scopes for each audit event model with filters applied
  # 2. Optionally filters scopes to a specific entity type (User/Project/Group/Instance)
  # 3. Applies keyset pagination to each scope independently
  # 4. Executes a UNION query to combine results from all scopes
  # 5. Preloads full records using (created_at, id) pairs for efficiency
  # 6. Returns paginated results with a cursor for the next page
  # Example usage:
  #   finder = AuditEvents::CombinedAuditEventFinder.new(
  #     params: {
  #       entity_type: 'Project',
  #       author_id: 123,
  #       created_after: 1.week.ago,
  #       per_page: 20,
  #       cursor: 'eyJpZCI6MTIzfQ=='
  #     }
  #   )
  #   result = finder.execute
  #   # => { records: [...], cursor_for_next_page: '...' }
  class CombinedAuditEventFinder < BaseAuditEventFinder
    include FromUnion

    AUDIT_EVENT_MODELS = [
      AuditEvents::InstanceAuditEvent,
      AuditEvents::UserAuditEvent,
      AuditEvents::ProjectAuditEvent,
      AuditEvents::GroupAuditEvent
    ].freeze

    ENTITY_TYPE_TO_MODEL = {
      'User' => AuditEvents::UserAuditEvent,
      'Project' => AuditEvents::ProjectAuditEvent,
      'Group' => AuditEvents::GroupAuditEvent,
      'Gitlab::Audit::InstanceScope' => AuditEvents::InstanceAuditEvent
    }.freeze

    def initialize(params: {})
      super
      @per_page = params[:per_page]
      @cursor = params[:cursor]
    end

    # Executes the main query flow:
    # 1. Build filtered scopes for each model
    # 2. Apply keyset pagination to each scope
    # 3. Execute UNION query
    # 4. Preload full records
    # 5. Return paginated result set
    def execute
      scopes = build_model_scopes
      scopes = filter_scopes_by_entity_type(scopes) if params[:entity_type].present?
      keyset_scopes = build_keyset_scopes(scopes)
      union_results = execute_union_query(keyset_scopes)
      preloaded_records = preload_records(union_results)

      has_next_page = union_results.size > per_page
      next_cursor = has_next_page ? generate_next_cursor(preloaded_records) : nil

      { records: preloaded_records, cursor_for_next_page: next_cursor }
    end

    def find(id)
      AUDIT_EVENT_MODELS.each do |model|
        audit_event = model.id_in(id).first
        return audit_event if audit_event
      end

      raise ActiveRecord::RecordNotFound
    end

    private

    attr_reader :per_page, :cursor

    def build_model_scopes
      AUDIT_EVENT_MODELS.map do |model|
        apply_filters(model.all).order_by('created_desc')
      end
    end

    def filter_scopes_by_entity_type(scopes)
      return scopes unless valid_entity_type?

      target_model = ENTITY_TYPE_TO_MODEL[params[:entity_type]]

      return scopes unless target_model

      scopes.select { |scope| scope.model == target_model }
    end

    def apply_filters(scope)
      scope = by_created_at(scope)
      scope = by_author(scope)
      by_entity(scope)
    end

    def build_keyset_scopes(scopes)
      return [] if scopes.empty?

      scopes.map do |scope|
        keyset_scope = build_keyset_order(scope)
        cursor_scope = apply_cursor_if_present(keyset_scope)
        add_select_and_limit(cursor_scope, scope.model)
      end
    end

    def build_keyset_order(scope)
      new_scope, success = Gitlab::Pagination::Keyset::SimpleOrderBuilder.build(scope)
      raise 'Failed to build keyset ordering' unless success

      new_scope
    end

    def apply_cursor_if_present(scope)
      return scope unless cursor

      cursor_conditions = parse_cursor_conditions
      return scope unless cursor_conditions

      order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(scope)
      order.apply_cursor_conditions(scope, cursor_conditions)
    end

    def add_select_and_limit(scope, model)
      scope
        .limit(per_page + 1)
        .select(:id, :created_at, "'#{model}' AS ar_class")
    end

    def parse_cursor_conditions
      return unless cursor

      result = ::Gitlab::Pagination::Keyset::Paginator::Base64CursorConverter.parse(cursor)

      { id: result[:id] }
    end

    def execute_union_query(keyset_scopes)
      return [] if keyset_scopes.empty?

      base_model = AUDIT_EVENT_MODELS.first

      base_model
        .from_union(keyset_scopes, remove_order: false)
        .order_by('created_desc')
        .limit(per_page + 1)
        .to_a
    end

    # Preloads full audit event records from their respective tables.
    # The UNION query only selects minimal columns (id, created_at, ar_class),
    # so we need to load the complete records using (created_at, id) pairs
    # for efficient batching.
    def preload_records(union_results)
      records_to_load = union_results.first(per_page)
      return [] if records_to_load.empty?

      grouped_records = records_to_load.group_by(&:ar_class)
      sorted_index = create_sorted_index(records_to_load)
      preloaded_records = load_grouped_records(grouped_records)

      preloaded_records.sort_by { |record| sorted_index[record.id] || Float::INFINITY }
    end

    def create_sorted_index(records)
      records.each_with_index.to_h { |record, index| [record.id, index] }
    end

    def load_grouped_records(grouped_records)
      grouped_records.flat_map do |ar_class_name, record_group|
        model_class = ar_class_name.constantize
        load_records_by_pairs(model_class, record_group).to_a
      end
    end

    def load_records_by_pairs(model_class, records)
      return model_class.none if records.empty?

      value_pairs = records.map { |r| [r.created_at.utc, r.id] }
      placeholders = build_placeholders(value_pairs.size)
      where_clause = "(created_at, id) IN (#{placeholders})"

      model_class.where(where_clause, *value_pairs.flatten) # rubocop: disable CodeReuse/ActiveRecord -- complex query building, not used anywhere else.
    end

    def build_placeholders(count)
      (['(?, ?)'] * count).join(', ')
    end

    def generate_next_cursor(records)
      return if records.empty?

      last_record = records.last
      cursor_attributes = {
        id: last_record.id
      }

      ::Gitlab::Pagination::Keyset::Paginator::Base64CursorConverter.dump(cursor_attributes)
    end

    def by_entity(audit_events)
      return audit_events unless valid_entity_id?

      model_class = audit_events.model

      case model_class.name
      when 'AuditEvents::UserAuditEvent'
        return audit_events unless params[:entity_type] == 'User'

        audit_events.by_user(params[:entity_id])
      when 'AuditEvents::ProjectAuditEvent'
        return audit_events unless params[:entity_type] == 'Project'

        audit_events.by_project(params[:entity_id])
      when 'AuditEvents::GroupAuditEvent'
        return audit_events unless params[:entity_type] == 'Group'

        audit_events.by_group(params[:entity_id])
      else
        audit_events
      end
    end

    def valid_entity_type?
      AuditEventFinder::VALID_ENTITY_TYPES.include?(params[:entity_type])
    end

    def valid_entity_id?
      params[:entity_id].to_i.nonzero?
    end
  end
end
