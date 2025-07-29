# frozen_string_literal: true

module EE
  module WorkItems
    module Type
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      # These widgets require some configuration at the group level
      # so we need to hide these for personal namespaces
      EXCLUDED_USER_NAMESPACE_LICENSED_WIDGETS = [
        ::WorkItems::Widgets::Iteration,
        ::WorkItems::Widgets::CustomFields,
        ::WorkItems::Widgets::Status
      ].freeze

      LICENSED_WIDGETS = {
        iterations: ::WorkItems::Widgets::Iteration,
        issue_weights: ::WorkItems::Widgets::Weight,
        requirements: [
          ::WorkItems::Widgets::VerificationStatus,
          ::WorkItems::Widgets::RequirementLegacy,
          ::WorkItems::Widgets::TestReports
        ],
        issuable_health_status: ::WorkItems::Widgets::HealthStatus,
        okrs: ::WorkItems::Widgets::Progress,
        epic_colors: ::WorkItems::Widgets::Color,
        custom_fields: ::WorkItems::Widgets::CustomFields,
        security_dashboard: ::WorkItems::Widgets::Vulnerabilities,
        work_item_status: ::WorkItems::Widgets::Status
      }.freeze

      LICENSED_TYPES = { epic: :epics, objective: :okrs, key_result: :okrs, requirement: :requirements }.freeze

      LICENSED_HIERARCHY_TYPES = {
        issue: { parent: { epic: :epics } },
        epic: { parent: { epic: :subepics }, child: { epic: :subepics, issue: :epics } }
      }.freeze

      class_methods do
        extend ::Gitlab::Utils::Override

        override :allowed_group_level_types
        def allowed_group_level_types(resource_parent)
          allowed_types = super

          allowed_types << 'epic' if resource_parent.licensed_feature_available?(:epics)

          allowed_types
        end
      end

      override :widgets
      def widgets(resource_parent)
        strong_memoize_with(:widgets, resource_parent) do
          unavailable_widgets = unlicensed_widget_classes(resource_parent)
          namespace = resource_parent.respond_to?(:namespace) ? resource_parent.namespace : resource_parent
          unavailable_widgets += EXCLUDED_USER_NAMESPACE_LICENSED_WIDGETS if namespace.user_namespace?

          unless resource_parent.root_ancestor.try(:work_item_status_feature_available?)
            unavailable_widgets << ::WorkItems::Widgets::Status
          end

          super.reject { |widget_def| unavailable_widgets.include?(widget_def.widget_class) }
        end
      end

      def status_lifecycle_for(namespace_id)
        custom_lifecycle_for(namespace_id) || system_defined_lifecycle
      end

      def custom_status_enabled_for?(namespace_id)
        return false unless namespace_id

        ::WorkItems::TypeCustomLifecycle.exists?(
          work_item_type_id: id,
          namespace_id: namespace_id
        )
      end

      def custom_lifecycle_for(namespace_id)
        return unless namespace_id

        ::WorkItems::Statuses::Custom::Lifecycle
          .includes(:statuses)
          .joins(:type_custom_lifecycles)
          .find_by(
            namespace_id: namespace_id,
            type_custom_lifecycles: { work_item_type_id: id, namespace_id: namespace_id }
          )
      end

      def system_defined_lifecycle
        ::WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(base_type.to_sym)
      end

      private

      def unlicensed_widget_classes(resource_parent)
        LICENSED_WIDGETS.flat_map do |licensed_feature, widget_class|
          widget_class unless resource_parent.licensed_feature_available?(licensed_feature)
        end.compact
      end

      override :supported_conversion_base_types
      def supported_conversion_base_types(resource_parent, user)
        ee_base_types = LICENSED_TYPES.flat_map do |type, licensed_feature|
          type.to_s if resource_parent.licensed_feature_available?(licensed_feature.to_sym)
        end.compact

        group = resource_parent.is_a?(Group) ? resource_parent : resource_parent.group

        ee_base_types -= %w[epic] unless Ability.allowed?(user, :create_epic, group)

        project = if resource_parent.is_a?(Project)
                    resource_parent
                  elsif resource_parent.respond_to?(:project)
                    resource_parent.project.presence
                  end

        ee_base_types -= %w[objective key_result] unless project && ::Feature.enabled?(:okrs_mvc, project)

        super + ee_base_types
      end

      override :authorized_types
      def authorized_types(types, resource_parent, relation)
        licenses_for_relation = LICENSED_HIERARCHY_TYPES[base_type.to_sym].try(:[], relation)
        return super unless licenses_for_relation

        types.select do |type|
          license_name = licenses_for_relation[type.base_type.to_sym]
          next type unless license_name

          resource_parent&.licensed_feature_available?(license_name)
        end
      end
    end
  end
end
