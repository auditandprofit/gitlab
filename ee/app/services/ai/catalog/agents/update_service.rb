# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class UpdateService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @agent = params[:agent]
          super
        end

        def execute
          return error_no_permissions(payload: payload) unless allowed?
          return error('Agent not found', payload: payload) unless valid_agent?

          agent_params = params.slice(:name, :description, :public)

          version_params = params.slice(:system_prompt, :tools, :user_prompt).stringify_keys
          version_params['tools']&.map!(&:id)

          agent.assign_attributes(agent_params)

          latest_version = agent.latest_version
          latest_version.definition = latest_version.definition.merge(version_params)
          latest_version.schema_version = Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION if latest_version.changed?

          # Changes to the agent record are also saved through latest_version
          if latest_version.save
            track_ai_item_events('update_ai_catalog_item', agent.item_type)
            return ServiceResponse.success(payload: payload)
          end

          error(latest_version.errors.full_messages, payload: payload)
        end

        private

        attr_reader :agent

        def valid_agent?
          agent && agent.agent?
        end

        def payload
          { item: agent }
        end
      end
    end
  end
end
