# frozen_string_literal: true

module Ai
  class AgentPresenter < Gitlab::View::Presenter::Delegated
    presents ::Ai::Agent, as: :agent

    def route_id
      agent.id
    end
  end
end
