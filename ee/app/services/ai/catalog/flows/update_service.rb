# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class UpdateService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params:)
          @flow = params[:flow]
          super
        end

        def execute
          return error_no_permissions(payload: payload) unless allowed?
          return error('Flow not found', payload: payload) unless valid_flow?

          item_params = params.slice(:name, :description, :public)
          flow.assign_attributes(item_params)

          return ServiceResponse.success(payload: payload) if flow.save

          error(flow.errors.full_messages, payload: payload)
        end

        private

        attr_reader :flow

        def valid_flow?
          flow && flow.flow?
        end

        def payload
          { flow: flow }
        end
      end
    end
  end
end
