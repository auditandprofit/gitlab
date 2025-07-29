# frozen_string_literal: true

module SecretsManagement
  class SecretPermission
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    # Project this permission belongs to
    attribute :project

    # Principal that has the permission (user, role, group)
    attribute :principal_id, :integer
    attribute :principal_type, :string

    # Resource the permission applies to (project, group)
    attribute :resource_id, :integer
    attribute :resource_type, :string

    # Additional metadata
    attribute :permissions
    attribute :granted_by, :integer
    attribute :expired_at, :string

    validate :ensure_active_secrets_manager
    validates :principal_id, :principal_type, presence: true
    validates :resource_id, :resource_type, presence: true
    validates :permissions, presence: true
    validate :validate_principal_types, :validate_resource_types, :validate_permissions, :validate_role_id
    validate :valid_resource, :valid_principal

    VALID_PRINCIPAL_TYPES = %w[User Role Group MemberRole].freeze
    VALID_RESOURCE_TYPES = %w[Project Group].freeze
    VALID_PERMISSIONS = %w[read update delete create].freeze
    VALID_ROLES = Gitlab::Access.sym_options.freeze

    delegate :secrets_manager, to: :project

    private

    def validate_principal_types
      return if VALID_PRINCIPAL_TYPES.include?(principal_type)

      errors.add(:principal_type, "must be one of: #{VALID_PRINCIPAL_TYPES.join(', ')}")
    end

    def validate_resource_types
      return if VALID_RESOURCE_TYPES.include?(resource_type)

      errors.add(:resource_type, "must be one of: #{VALID_RESOURCE_TYPES.join(', ')}")
    end

    def validate_permissions
      permissions&.include?('read') || errors.add(:permissions, 'must include read')

      permissions&.each do |permission|
        unless VALID_PERMISSIONS.include?(permission)
          errors.add(:permissions, "contains invalid permission: #{permission}")
        end
      end
    end

    def validate_role_id
      return unless principal_type == 'Role' && VALID_ROLES.values.exclude?(principal_id)

      errors.add(:principal_id, "must be one of: #{VALID_ROLES} for Role type")
    end

    def valid_resource
      case resource_type
      when 'Project'
        errors.add(:resource_id, "Project does not exist") if Project.find_by_id(resource_id).nil?
      when 'Group'
        errors.add(:resource_id, "Group does not exist") if Group.find_by_id(resource_id).nil?
      end
    end

    def valid_principal
      return if principal_type == 'Role'

      case principal_type
      when 'User'
        valid_user
      when 'Group'
        valid_group
      when 'MemberRole'
        valid_member_role
      end
    end

    def valid_user
      user = User.find_by_id(principal_id)
      if user.nil?
        errors.add(:principal_id, "User does not exist")
      else
        return unless VALID_RESOURCE_TYPES.include?(resource_type)

        unless resource_type&.constantize&.find_by_id(resource_id)&.member?(user)
          errors.add(:principal_id, "User is not a member of the #{resource_type}")
        end
      end
    end

    def valid_group
      group = Group.find_by_id(principal_id)
      if group.nil?
        errors.add(:principal_id, "Group does not exist")
      else
        # currently we allow only creation of permissions only for Project,
        # but group validations to be added when Group level secrets are introduced
        project = resource_type.constantize.find_by_id(resource_id)
        unless group_has_access_to_project?(group, project)
          errors.add(:principal_id, "Group is not a descendant of the project")
        end
      end
    end

    def valid_member_role
      member_role = MemberRole.find_by_id(principal_id)
      if member_role.nil?
        errors.add(:principal_id, "Member Role does not exist")
      else
        unless project.namespace.self_and_ancestors.where(id: member_role.namespace_id).exists?
          errors.add(:principal_id, "Member Role does not have access to this project")
        end
      end
    end

    def group_has_access_to_project?(group, project)
      # Check if the project belongs directly to the group or its subgroups
      return true if project.namespace == group
      return true if project.group && (project.group == group || project.group.ancestor_ids.include?(group.id))

      # Check if the project is explicitly shared with the group using direct query
      return true if project.project_group_links.where(group_id: group.id).exists?

      false
    end

    def ensure_active_secrets_manager
      errors.add(:base, 'Project secrets manager is not active.') unless project.secrets_manager&.active?
    end
  end
end
