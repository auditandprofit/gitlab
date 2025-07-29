# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Utils
        class ChatAuthorizer < Gitlab::Llm::Utils::Authorizer
          def self.context(context:)
            unless context.current_user
              return Response.new(allowed: false,
                message: no_access_message)
            end

            if context.resource && context.container
              authorization_container = container(container: context.container, user: context.current_user)
              if authorization_container.allowed?
                resource(resource: context.resource, user: context.current_user)
              else
                authorization_container
              end
            elsif context.resource
              resource(resource: context.resource, user: context.current_user)
            elsif context.container
              container(container: context.container, user: context.current_user)
            else
              user(user: context.current_user)
            end
          end

          def self.container(container:, user:)
            response = super(container: container, user: user)
            return response unless response.allowed?

            user(user: user)
          end

          def self.user(user:)
            response = super(user: user)
            return response unless response.allowed?

            allowed = user.can?(:access_duo_chat)
            message = no_access_message unless allowed
            Response.new(allowed: allowed, message: message)
          end
        end
      end
    end
  end
end
