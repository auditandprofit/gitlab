# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      include FromUnion
      include EachBatch
      include Sortable

      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true
      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'
      has_many :checkpoint_writes, class_name: 'Ai::DuoWorkflows::CheckpointWrite'
      has_many :events, class_name: 'Ai::DuoWorkflows::Event'
      has_many :workflows_workloads, class_name: 'Ai::DuoWorkflows::WorkflowsWorkload'
      has_many :workloads, through: :workflows_workloads, disable_joins: true

      validates :status, presence: true
      validates :goal, length: { maximum: 16_384 }
      validates :image, length: { maximum: 2048 }, allow_blank: true

      validate :only_known_agent_priviliges
      validate :only_known_pre_approved_agent_privileges
      validate :pre_approved_privileges_included_in_agent_privileges, on: :create

      enum :environment, { ide: 1, web: 2 }

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }
      scope :for_user, ->(user_id) { where(user_id: user_id) }
      scope :for_project, ->(project) { where(project: project) }
      scope :stale_since, ->(time) { where(updated_at: ...time).order(updated_at: :asc, id: :asc) }

      scope :with_workflow_definition, ->(definition) { where(workflow_definition: definition) }
      scope :with_environment, ->(environment) { where(environment: environment) }
      scope :from_pipeline, -> { where.not(workflow_definition: :chat).with_environment(:web) }
      class AgentPrivileges
        READ_WRITE_FILES  = 1
        READ_ONLY_GITLAB  = 2
        READ_WRITE_GITLAB = 3
        RUN_COMMANDS      = 4
        USE_GIT           = 5
        RUN_MCP_TOOLS     = 6

        ALL_PRIVILEGES = {
          READ_WRITE_FILES => {
            name: "read_write_files",
            description: "Allow local filesystem read/write access"
          }.freeze,
          READ_ONLY_GITLAB => {
            name: "read_only_gitlab",
            description: "Allow read only access to GitLab APIs"
          }.freeze,
          READ_WRITE_GITLAB => {
            name: "read_write_gitlab",
            description: "Allow write access to GitLab APIs"
          }.freeze,
          RUN_COMMANDS => {
            name: "run_commands",
            description: "Allow running any commands"
          }.freeze,
          USE_GIT => {
            name: "use_git",
            description: "Allow git commits, push and other git commands"
          }.freeze,
          RUN_MCP_TOOLS => {
            name: "run_mcp_tools",
            description: "Allow running MCP tools"
          }.freeze
        }.freeze

        DEFAULT_PRIVILEGES = [
          READ_WRITE_FILES,
          READ_ONLY_GITLAB
        ].freeze
      end

      def only_known_agent_priviliges
        self.agent_privileges ||= AgentPrivileges::DEFAULT_PRIVILEGES

        agent_privileges.each do |privilege|
          unless AgentPrivileges::ALL_PRIVILEGES.key?(privilege)
            errors.add(:agent_privileges, "contains an invalid value #{privilege}")
          end
        end
      end

      def chat?
        workflow_definition == 'chat'
      end

      def archived?
        created_at <= CHECKPOINT_RETENTION_DAYS.days.ago
      end

      def stalled?
        !created? && !checkpoints.exists?
      end

      def last_executor_logs_url
        last_workload&.logs_url
      end

      def last_workload
        @last_workload ||= workloads.order(created_at: :desc).first
      end

      def project_level?
        project_id.present?
      end

      def namespace_level?
        namespace_id.present?
      end

      def resource_parent
        project || namespace
      end

      def mcp_enabled?
        return true if resource_parent.root_ancestor.duo_workflow_mcp_enabled

        false
      end

      private

      def only_known_pre_approved_agent_privileges
        return if pre_approved_agent_privileges.nil?

        pre_approved_agent_privileges.each do |privilege|
          next if AgentPrivileges::ALL_PRIVILEGES.key?(privilege)

          errors.add(:pre_approved_agent_privileges, "contains an invalid value #{privilege}")
        end
      end

      def pre_approved_privileges_included_in_agent_privileges
        # both columns will use db default values which are equal
        return if pre_approved_agent_privileges.nil? && agent_privileges.nil?

        pre_approved_privileges_with_defaults = pre_approved_agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES
        agent_privileges_with_defaults = agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES

        pre_approved_privileges_with_defaults.each do |privilege|
          next if agent_privileges_with_defaults.include?(privilege)

          errors.add(
            :pre_approved_agent_privileges,
            "contains privilege #{privilege} not present in agent_privileges"
          )
        end
      end

      state_machine :status, initial: :created do
        event :start do
          transition created: :running
        end

        event :pause do
          transition running: :paused
        end

        event :require_input do
          transition running: :input_required
        end

        event :require_plan_approval do
          transition running: :plan_approval_required
        end

        event :require_tool_call_approval do
          transition running: :tool_call_approval_required
        end

        event :resume do
          transition [
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => :running
        end

        event :retry do
          transition [:running, :stopped, :failed] => :running
        end

        event :finish do
          transition running: :finished
        end

        event :drop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => :failed
        end

        event :stop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => :stopped
        end

        state :created, value: 0
        state :running, value: 1
        state :paused, value: 2
        state :finished, value: 3
        state :failed, value: 4
        state :stopped, value: 5
        state :input_required, value: 6
        state :plan_approval_required, value: 7
        state :tool_call_approval_required, value: 8
      end
    end
  end
end
