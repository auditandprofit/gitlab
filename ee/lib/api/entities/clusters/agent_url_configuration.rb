# frozen_string_literal: true

module API
  module Entities
    module Clusters
      class AgentUrlConfiguration < Grape::Entity
        expose :id
        expose :agent_id
        expose :url
        expose :public_key
        expose :client_cert
        expose :ca_cert
        expose :tls_host

        def public_key
          return unless object.public_key

          Base64.strict_encode64(object.public_key)
        end
      end
    end
  end
end
