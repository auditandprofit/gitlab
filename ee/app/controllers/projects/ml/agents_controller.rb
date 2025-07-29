# frozen_string_literal: true

module Projects
  module Ml
    class AgentsController < Projects::ApplicationController
      before_action :authorize_read_ai_agents!

      feature_category :mlops

      def index; end

      private

      def authorize_read_ai_agents!
        render_404 unless can?(current_user, :read_ai_agents, @project)
      end
    end
  end
end
