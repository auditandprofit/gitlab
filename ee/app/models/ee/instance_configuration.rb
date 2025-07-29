# frozen_string_literal: true

module EE
  module InstanceConfiguration # rubocop:disable Gitlab/BoundedContexts -- class that we are extending is not namespaced
    extend ::Gitlab::Utils::Override

    private

    override :configuration
    def configuration
      super.merge(ai_gateway_url: ::Gitlab::AiGateway.url)
    end
  end
end
