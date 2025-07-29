# frozen_string_literal: true

module EE
  module UserPreference
    extend ActiveSupport::Concern

    prepended do
      belongs_to :default_duo_add_on_assignment, class_name: 'GitlabSubscriptions::UserAddOnAssignment', optional: true

      validates :roadmap_epics_state, allow_nil: true, inclusion: {
        in: ::Epic.available_states.values, message: "%{value} is not a valid epic state id"
      }

      validates :epic_notes_filter, inclusion: { in: ::UserPreference::NOTES_FILTERS.values }, presence: true

      validate :check_seat_for_default_duo_assigment, if: :default_duo_add_on_assignment_id_changed?

      def eligible_duo_add_on_assignments
        assignable_enum_value = ::GitlabSubscriptions::AddOn.names.values_at(
          *::GitlabSubscriptions::AddOn::SEAT_ASSIGNABLE_DUO_ADD_ONS
        )

        GitlabSubscriptions::UserAddOnAssignment
                                    .by_user(user)
                                    .with_namespaces
                                    .joins(add_on_purchase: :add_on)
                                    .where(add_on_purchase: { subscription_add_ons: { name: assignable_enum_value } })
                                    .where.not(add_on_purchase: { namespace_id: nil })
      end

      def check_seat_for_default_duo_assigment
        return if default_duo_add_on_assignment_id.nil?

        return if eligible_duo_add_on_assignments.exists?(id: default_duo_add_on_assignment_id)

        errors.add(:default_duo_add_on_assignment_id,
          "No Duo seat assignments with namespace found with ID #{default_duo_add_on_assignment_id}")
      end

      def get_default_duo_namespace
        return default_duo_add_on_assignment.add_on_purchase.namespace if default_duo_add_on_assignment.present?

        assignments = eligible_duo_add_on_assignments.limit(2).to_a
        return if assignments.size != 1

        assignments.first.add_on_purchase.namespace
      end
    end
  end
end
