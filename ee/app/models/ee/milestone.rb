# frozen_string_literal: true

module EE
  module Milestone
    extend ActiveSupport::Concern

    prepended do
      include Elastic::ApplicationVersionedSearch
      include Elastic::UpdateAssociatedEpicsOnDateChange

      has_many :boards

      elastic_index_dependant_association :issues,
        on_change: :title,
        depends_on_finished_migration: :add_work_item_milestone_data

      elastic_index_dependant_association :issues,
        on_change: [:due_date, :start_date],
        depends_on_finished_migration: :add_extra_fields_to_work_items

      elastic_index_dependant_association :issues,
        on_change: :state,
        depends_on_finished_migration: :index_work_items_milestone_state
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :with_web_entity_associations
      def with_web_entity_associations
        super.preload(project: [:invited_groups, { group: [:saml_provider] }])
      end
    end

    def supports_milestone_charts?
      resource_parent&.feature_available?(:milestone_charts) && weight_available?
    end

    alias_method :supports_timebox_charts?, :supports_milestone_charts?
  end
end
