# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnPurchase < ApplicationRecord
    include EachBatch
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    CLEANUP_DELAY_PERIOD = 14.days
    NORMALIZED_ADD_ON_NAME = { 'code_suggestions' => 'duo_pro' }.freeze
    NORMALIZED_ADD_ON_NAME_INVERTED = NORMALIZED_ADD_ON_NAME.invert.freeze

    belongs_to :add_on, foreign_key: :subscription_add_on_id, inverse_of: :add_on_purchases
    belongs_to :namespace, optional: true
    belongs_to :organization, class_name: 'Organizations::Organization'
    has_many :assigned_users, class_name: 'GitlabSubscriptions::UserAddOnAssignment', inverse_of: :add_on_purchase,
      dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
    has_many :users, through: :assigned_users

    validates :add_on, :expires_on, presence: true
    validates :add_on, :started_at, presence: true
    validate :valid_namespace, if: :gitlab_com?
    validates :subscription_add_on_id, uniqueness: { scope: :namespace_id }
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :purchase_xid,
      presence: true,
      length: { maximum: 255 }

    scope :active, -> {
      today = Date.current

      where('started_at IS NULL OR started_at <= ?', today).where('? < expires_on', today)
    }
    scope :ready_for_cleanup, -> {
      where('expires_on < ?', CLEANUP_DELAY_PERIOD.ago.to_date)
    }
    scope :has_assigned_users, -> {
      where(
        "EXISTS (
          SELECT 1
          FROM subscription_user_add_on_assignments
          WHERE add_on_purchase_id = subscription_add_on_purchases.id
        )")
    }
    scope :trial, -> { where(trial: true) }
    scope :non_trial, -> { where(trial: false) }
    scope :by_add_on_name, ->(name) { joins(:add_on).where(add_on: { name: name }) }
    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
    scope :for_self_managed, -> { where(namespace: nil) }
    scope :for_gitlab_duo_pro, -> { where(subscription_add_on_id: AddOn.code_suggestions.pick(:id)) }
    scope :for_product_analytics, -> { where(subscription_add_on_id: AddOn.product_analytics.pick(:id)) }
    scope :for_duo_enterprise, -> { where(subscription_add_on_id: AddOn.duo_enterprise.pick(:id)) }
    scope :for_duo_amazon_q, -> { where(subscription_add_on_id: AddOn.duo_amazon_q.pick(:id)) }
    scope :for_duo_self_hosted, -> { where(subscription_add_on_id: AddOn.duo_self_hosted.pick(:id)) }
    scope :for_duo_core, -> { where(subscription_add_on_id: AddOn.duo_core.select(:id)) }
    # this executes 2 queries to the `AddOn` table, 1 for `code_suggestions` (duo pro), and 1 for `duo_enterprise`
    scope :for_duo_pro_or_duo_enterprise, -> { for_gitlab_duo_pro.or(for_duo_enterprise) }
    # this queries the `AddOn` table *once* for the duo add-ons (`code_suggestions` and `duo_enterprise`)
    scope :for_duo_add_ons, -> { where(subscription_add_on_id: AddOn.duo_add_ons.select(:id)) }
    # Finds all active add-on purchases that match the given add_on_names and resource.
    # add_on_names:
    #     Array of add-on names to filter the purchases by.
    # resource:
    #     One of :instance, `User`, `Project` or `Group` to scope the search.
    #     Allowed to be nil, in which case results will not be filtered by resource.
    scope :for_active_add_ons, ->(add_on_names, resource) do
      scope = by_add_on_name(add_on_names).active

      # On SM/Dedicated, or when requesting instance-wide purchases, we do not need to check namespace rules.
      if resource == :instance || !::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        return scope.for_self_managed
      end

      # On gitlab.com, we support checking either via the user's billable group memberships,
      # or via the group directly.
      return scope.for_user(resource) if resource.is_a?(User)
      return scope.by_namespace(resource.root_ancestor) if resource.respond_to?(:root_ancestor)

      # Fall through to case that allows the caller to apply custom scopes.
      scope
    end
    scope :for_seat_assignable_duo_add_ons, -> do
      where(subscription_add_on_id: AddOn.seat_assignable_duo_add_ons.select(:id))
    end
    scope :for_duo_core_pro_or_enterprise, -> { for_duo_core.or(for_duo_pro_or_duo_enterprise) }
    scope :for_user, ->(user) { by_namespace(user.billable_gitlab_duo_pro_root_group_ids) }
    scope :assigned_to_user, ->(user) do
      active.joins(:assigned_users).merge(UserAddOnAssignment.by_user(user))
    end

    scope :requiring_assigned_users_refresh, ->(limit) do
      # Fetches add_on_purchases whose assigned_users have not been refreshed in last 8 hours.
      # Used primarily by BulkRefreshUserAssignmentsWorker, which is scheduled every 4 hours
      # by ScheduleBulkRefreshUserAssignmentsWorker.
      for_seat_assignable_duo_add_ons
        .where("last_assigned_users_refreshed_at < ? OR last_assigned_users_refreshed_at is NULL", 8.hours.ago)
        .limit(limit)
    end

    delegate :name, :seat_assignable?, to: :add_on, prefix: true

    # Finds all active add-on purchases that grant the given Unit Primitive ("entitlement")
    # for the given resource. See also: for_active_add_ons.
    #
    # unit_primitive_name:
    #     Symbol representing the unit primitive to find active add-ons for.
    # resource:
    #     One of :instance, `User`, `Project` or `Group` to scope the search.
    #     Passing :instance will match all add-on purchases on this instance.
    #     Passing a `User`, `Project` or `Group` will match add-on purchases that are
    #     scoped to the root namespace of these resources.
    def self.find_for_unit_primitive(unit_primitive_name, resource)
      unless resource == :instance || [Group, Project, User].any? { |klass| resource.is_a?(klass) }
        raise ArgumentError, 'resource must be :instance, or a User, Group or Project'
      end

      unit_primitive = ::Gitlab::CloudConnector::DataModel::UnitPrimitive.find_by_name(unit_primitive_name)
      return none unless unit_primitive

      add_on_names = unit_primitive.add_ons.map(&:name)
      normalized_names = add_on_names.map { |name| NORMALIZED_ADD_ON_NAME_INVERTED[name] || name }

      for_active_add_ons(normalized_names, resource)
    end

    def self.exists_for_unit_primitive?(unit_primitive_name, resource)
      find_for_unit_primitive(unit_primitive_name, resource).exists?
    end

    def self.find_for_active_duo_add_ons(resource)
      for_active_add_ons(AddOn::DUO_ADD_ONS, resource)
    end

    def self.active_duo_add_ons_exist?(resource)
      find_for_active_duo_add_ons(resource).exists?
    end

    def self.find_by_namespace_and_add_on(namespace, add_on)
      find_by(namespace: namespace, add_on: add_on)
    end

    def self.next_candidate_requiring_assigned_users_refresh
      requiring_assigned_users_refresh(1)
        .order('last_assigned_users_refreshed_at ASC NULLS FIRST')
        .lock('FOR UPDATE SKIP LOCKED')
        .includes(:namespace)
        .first
    end

    def self.uniq_add_on_names
      joins(:add_on).pluck(:name).uniq
    end

    def self.uniq_namespace_ids
      pluck(:namespace_id).compact.uniq
    end

    def already_assigned?(user)
      assigned_users.where(user: user).exists?
    end

    def active?
      today = Date.current

      (started_at.nil? || started_at <= today) && today < expires_on
    end

    def expired?
      expires_on <= Date.current
    end

    def delete_ineligible_user_assignments_in_batches!(batch_size: 50)
      deleted_assignments_count = 0

      assigned_users.each_batch(of: batch_size) do |batch|
        ineligible_user_ids = filter_ineligible_assigned_user_ids(batch.pluck_user_ids.to_set)
        deletable_assigned_users = batch.for_user_ids(ineligible_user_ids)
        count = deletable_assigned_users.count
        deleted_assignments_count += count

        log_ineligible_users_add_on_assignments_deletion(ineligible_user_ids) if count > 0

        # rubocop:disable Cop/DestroyAll -- callbacks required
        deletable_assigned_users.destroy_all
        # rubocop:enable Cop/DestroyAll

        cache_keys = ineligible_user_ids.map do |user_id|
          User.duo_pro_cache_key_formatted(user_id)
        end

        Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      deleted_assignments_count
    end

    def lock_key_for_refreshing_user_assignments
      "#{self.class.name.underscore}:user_refresh:#{id}"
    end

    def normalized_add_on_name
      NORMALIZED_ADD_ON_NAME[add_on_name] || add_on_name
    end

    private

    def log_ineligible_users_add_on_assignments_deletion(user_ids)
      Gitlab::AppLogger.info(
        message: 'Ineligible UserAddOnAssignments destroyed',
        user_ids: user_ids.to_a,
        add_on: add_on.name,
        add_on_purchase: id,
        namespace: namespace&.path
      )
    end

    def filter_ineligible_assigned_user_ids(assigned_user_ids)
      return assigned_user_ids - saas_eligible_user_ids if namespace

      assigned_user_ids - self_managed_eligible_users_relation.where(id: assigned_user_ids).pluck(:id)
    end

    def saas_eligible_user_ids
      @eligible_user_ids ||= namespace.gitlab_duo_eligible_user_ids
    end

    def self_managed_eligible_users_relation
      @self_managed_eligible_users_relation ||= GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(
        add_on_type: add_on_name.to_sym
      ).execute
    end

    def gitlab_com?
      ::Gitlab::CurrentSettings.should_check_namespace_plan?
    end

    def valid_namespace
      return if namespace.present? && namespace.root? && namespace.group_namespace?

      errors.add(:namespace, :invalid)
    end
  end
end
