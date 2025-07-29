# frozen_string_literal: true

module Search
  module Zoekt
    class EnabledNamespace < ApplicationRecord
      include EachBatch

      self.table_name = 'zoekt_enabled_namespaces'

      belongs_to :namespace, class_name: 'Namespace',
        foreign_key: :root_namespace_id, inverse_of: :zoekt_enabled_namespace

      has_many :indices, class_name: '::Search::Zoekt::Index',
        foreign_key: :zoekt_enabled_namespace_id, inverse_of: :zoekt_enabled_namespace,
        dependent: :nullify # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
      has_many :nodes, through: :indices

      has_many :replicas, dependent: :destroy, # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
        foreign_key: :zoekt_enabled_namespace_id, inverse_of: :zoekt_enabled_namespace

      validate :only_root_namespaces_can_be_indexed

      scope :for_root_namespace_id, ->(root_namespace_id) { where(root_namespace_id: root_namespace_id) }
      scope :preload_storage_statistics, -> { includes(namespace: :root_storage_statistics) }
      scope :recent, -> { order(id: :desc) }
      scope :search_enabled, -> { where(search: true) }
      scope :search_disabled, -> { where(search: false) }
      scope :with_limit, ->(maximum) { limit(maximum) }
      scope :with_missing_indices, -> { left_joins(:indices).where(zoekt_indices: { zoekt_enabled_namespace_id: nil }) }
      scope :with_all_ready_indices, -> do
        raw_sql = 'min(zoekt_indices.state) = :state AND max(zoekt_indices.state) = :state'
        joins(:indices).group(:id).having(raw_sql, state: Search::Zoekt::Index.states[:ready])
      end

      validates :metadata, json_schema: { filename: 'zoekt_enabled_namespaces_metadata' }

      def self.destroy_namespaces_with_expired_subscriptions!
        before_date = Time.zone.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD

        each_batch(column: :root_namespace_id) do |batch|
          namespace_ids = batch.pluck(:root_namespace_id) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- it is limited by each_batch already

          namespace_with_subscription_ids = GitlabSubscription.where(namespace_id: namespace_ids)
            .with_a_paid_hosted_plan
            .not_expired(before_date: before_date)
            .pluck(:namespace_id) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- it is limited by each_batch already

          namespace_to_remove_ids = namespace_ids - namespace_with_subscription_ids
          next if namespace_to_remove_ids.empty?

          where(root_namespace_id: namespace_to_remove_ids).find_each(&:destroy)
        end
      end

      def self.update_last_used_storage_bytes!
        find_each(&:update_last_used_storage_bytes!)
      end

      def self.with_rollout_blocked
        return where.not(last_rollout_failed_at: nil) if Search::Zoekt::Settings.rollout_retry_interval.nil?

        where(last_rollout_failed_at: Search::Zoekt::Settings.rollout_retry_interval.ago..)
      end

      def self.with_rollout_allowed
        scope = where(last_rollout_failed_at: nil)
        return scope if Search::Zoekt::Settings.rollout_retry_interval.nil?

        scope.or(where(last_rollout_failed_at: ...Search::Zoekt::Settings.rollout_retry_interval.ago))
      end

      def update_last_used_storage_bytes!
        size = replicas.joins(:indices)
                       .group('zoekt_replicas.id')
                       .pluck('sum(zoekt_indices.used_storage_bytes)') # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- It is limited by the number of replicas. Right now it's one
                       .max
                       .to_i

        update_column(:metadata, metadata.merge(last_used_storage_bytes: size))
      end

      private

      def only_root_namespaces_can_be_indexed
        return if namespace&.root?

        errors.add(:root_namespace_id, 'Only root namespaces can be indexed')
      end
    end
  end
end
