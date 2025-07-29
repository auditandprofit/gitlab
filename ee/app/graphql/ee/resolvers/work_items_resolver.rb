# frozen_string_literal: true

module EE
  module Resolvers
    module WorkItemsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      include ::WorkItems::IterationArgumentHelpers

      prepended do
        argument :verification_status_widget, ::Types::WorkItems::Widgets::VerificationStatusFilterInputType,
          required: false,
          description: 'Input for verification status widget filter. Ignored if `work_items_alpha` is disabled.'
        argument :requirement_legacy_widget, ::Types::WorkItems::Widgets::RequirementLegacyFilterInputType,
          required: false,
          deprecated: { reason: 'Use work item IID filter instead', milestone: '15.9' },
          description: 'Input for legacy requirement widget filter.'
        argument :health_status_filter, ::Types::HealthStatusFilterEnum,
          required: false,
          description: 'Health status of the work item, "none" and "any" values are supported.'
        argument :weight, GraphQL::Types::String,
          required: false,
          description: 'Weight applied to the work item, "none" and "any" values are supported.'
        argument :weight_wildcard_id, ::Types::WeightWildcardIdEnum,
          required: false,
          description: 'Filter by weight ID wildcard. Incompatible with weight.'
        argument :custom_field, [::Types::WorkItems::Widgets::CustomFieldFilterInputType],
          required: false,
          experiment: { milestone: '17.10' },
          description: 'Filter by custom fields.',
          prepare: ->(custom_fields, _ctx) { Array(custom_fields).inject({}, :merge) }
        argument :status, ::Types::WorkItems::Widgets::StatusFilterInputType,
          required: false,
          description: 'Filter by status.',
          experiment: { milestone: '18.0' }
        argument :iteration_id, [::GraphQL::Types::ID, { null: true }],
          required: false,
          description: 'List of iteration Global IDs applied to the issue.'
        argument :iteration_wildcard_id, ::Types::IterationWildcardIdEnum,
          required: false,
          description: 'Filter by iteration ID wildcard.'
        argument :iteration_cadence_id, [::Types::GlobalIDType[::Iterations::Cadence]],
          required: false,
          description: 'Filter by a list of iteration cadence IDs.'

        validates mutually_exclusive: [:weight, :weight_wildcard_id]
        validates mutually_exclusive: [:iteration_id, :iteration_wildcard_id]
      end

      override :resolve_with_lookahead
      def resolve_with_lookahead(**args)
        args.delete(:verification_status_widget) unless resource_parent&.work_items_alpha_feature_flag_enabled?

        super
      end

      private

      override :prepare_finder_params
      def prepare_finder_params(args)
        params = super
        prepare_health_status_params(args)
        rewrite_param_name(params, :weight_wildcard_id, :weight)
        args[:not] = args[:not].to_h if args[:not]
        args[:iteration_id] = iteration_ids_from_args(args) if args[:iteration_id].present?
        args[:not][:iteration_id] = iteration_ids_from_args(args[:not]) if args.dig(:not, :iteration_id).present?
        args[:iteration_cadence_id] = iteration_cadence_ids_from_args(args) if args[:iteration_cadence_id].present?

        rewrite_param_name(params, :iteration_wildcard_id, :iteration_id)
        params
      end

      override :widget_preloads
      def widget_preloads
        super.merge(
          verification_status: { requirement: :recent_test_reports },
          progress: :progress,
          color: :color,
          test_reports: :test_reports
        )
      end

      def prepare_health_status_params(args)
        args[:health_status] = args.delete(:health_status_filter) if args[:health_status_filter].present?
      end
    end
  end
end
