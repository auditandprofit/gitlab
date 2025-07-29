# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillDuoCoreForExistingSubscription
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        TODAY = Date.current
        GRACE_PERIOD_AFTER_EXPIRATION = 14.days.freeze
        DEFAULT_EXPIRATION_PERIOD = 5.years.freeze
        PAID_HOSTED_PLANS = %w[bronze silver premium gold ultimate ultimate_trial ultimate_trial_paid_customer
          premium_trial opensource].freeze

        prepended do
          operation_name :backfill_duo_core_for_existing_subscription
          feature_category :'add-on_provisioning'
          scope_to ->(relation) {
            relation
              .joins('JOIN plans ON gitlab_subscriptions.hosted_plan_id = plans.id')
              .where('plans.name' => PAID_HOSTED_PLANS)
          }
        end

        class MigrationAddOn < ::ApplicationRecord
          self.table_name = :subscription_add_ons

          enum :name, {
            duo_core: 5
          }
        end

        class MigrationAddOnPurchase < ::ApplicationRecord
          self.table_name = :subscription_add_on_purchases
        end

        class MigrationNamespace < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled
        end

        override :perform
        def perform
          duo_core_add_on_id = MigrationAddOn.duo_core.pick(:id)

          each_sub_batch do |sub_batch|
            eligible_subscriptions = sub_batch
                    .where("end_date IS NULL OR end_date >= ?", TODAY)
                    .joins('JOIN namespaces ON gitlab_subscriptions.namespace_id = namespaces.id')
                    .joins(
                      "LEFT OUTER JOIN subscription_add_on_purchases as sa ON " \
                        "sa.namespace_id = gitlab_subscriptions.namespace_id AND " \
                        "sa.subscription_add_on_id = #{ActiveRecord::Base.connection.quote(duo_core_add_on_id)}"
                    )
                    .where(sa: { id: nil })
                    .where(namespaces: { type: 'Group', parent_id: nil })
                    .select('gitlab_subscriptions.*, namespaces.organization_id')

            records_to_create = prepare_records_for_bulk_insert(eligible_subscriptions, duo_core_add_on_id)

            next unless records_to_create.any?

            MigrationAddOnPurchase.insert_all(
              records_to_create,
              unique_by: [:subscription_add_on_id, :namespace_id], returning: false
            )
          end
        end

        private

        def prepare_records_for_bulk_insert(eligible_subscriptions, duo_core_add_on_id)
          eligible_subscriptions.map do |subscription|
            trial = subscription.trial.presence || false

            started_at = trial ? subscription.trial_starts_on : subscription.start_date
            expires_on = trial ? subscription.trial_ends_on : subscription.end_date

            started_at ||= TODAY
            expires_on ||= TODAY + DEFAULT_EXPIRATION_PERIOD
            expires_on += GRACE_PERIOD_AFTER_EXPIRATION unless trial

            {
              subscription_add_on_id: duo_core_add_on_id,
              namespace_id: subscription.namespace_id,
              quantity: subscription.seats > 0 ? subscription.seats : 10000,
              started_at: started_at,
              expires_on: expires_on,
              purchase_xid: 'duo_core_backfill_2025',
              trial: false,
              organization_id: subscription.organization_id
            }
          end
        end
      end
    end
  end
end
