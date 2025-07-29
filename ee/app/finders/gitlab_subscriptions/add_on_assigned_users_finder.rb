# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnAssignedUsersFinder
    include Gitlab::Utils::StrongMemoize

    def initialize(current_user, namespace, add_on_name:)
      @current_user = current_user
      @namespace = namespace
      @add_on_name = add_on_name
    end

    def execute
      add_on_purchase = GitlabSubscriptions::AddOnPurchase
        .by_add_on_name(add_on_name).by_namespace([namespace.root_ancestor, nil]).active.first

      return User.none unless add_on_purchase

      add_on_purchase.users.by_ids(namespace_members.reselect(:user_id))
    end

    private

    attr_reader :namespace, :current_user, :add_on_name

    def namespace_members
      # rubocop:disable CodeReuse/Finder -- member finders logic is way too complex to reconstruct it with scopes.
      if namespace.is_a?(Namespaces::ProjectNamespace)
        MembersFinder.new(namespace.project, current_user).execute(include_relations: %i[direct inherited descendants])
      else
        GroupMembersFinder.new(namespace, current_user).execute(include_relations: %i[direct inherited descendants])
      end
      # rubocop:enable CodeReuse/Finder
    end
  end
end
