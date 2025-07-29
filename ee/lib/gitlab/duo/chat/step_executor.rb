# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      class StepExecutor
        include Gitlab::Utils::StrongMemoize
        include Langsmith::RunHelpers
        include ::Gitlab::Llm::Concerns::Logger

        DEFAULT_TIMEOUT = 60.seconds
        CHAT_V2_ENDPOINT = '/v2/chat/agent'
        EVENT_DELIMITER = "\n"
        EVENT_REGEX = /(\{.*\})#{EVENT_DELIMITER}/i

        ConnectionError = Class.new(StandardError)

        attr_reader :agent_steps

        def initialize(user, feature_setting = nil)
          @user = user
          @feature_setting = feature_setting
          @agent_steps = []
          @event_parser = AgentEventParser.new
        end

        def step(params)
          events = []

          perform_agent_request(params) do |event_json|
            event = event_parser.parse(event_json)

            next unless event

            log_conditional_info(user, message: "Received an event from v2/chat/agent", event_name: 'event_received',
              ai_component: 'duo_chat', ai_event: event)

            yield event if block_given?

            if event.instance_of? AgentEvents::Action
              step = {}
              step[:thought] = event.thought
              step[:tool] = event.tool
              step[:tool_input] = event.tool_input

              @agent_steps.append(action: step)
            end

            events.append(event)
          end

          events
        end
        traceable :step, name: 'Step forward Duo Chat Agent', run_type: 'chain'

        def update_observation(observation)
          if @agent_steps.empty?
            log_error(message: "Failed to update observation", event_name: 'agent_steps_empty',
              ai_component: 'duo_chat')
            return
          end

          @agent_steps.last[:observation] = observation
        end

        private

        attr_reader :user, :event_parser, :feature_setting

        def perform_agent_request(params)
          log_conditional_info(user, message: "Request to v2/chat/agent",
            event_name: 'performing_request',
            ai_component: 'duo_chat',
            params: params)

          # V2 Chat Agent in AI Gateway streams events as response, however,
          # Gitlab::HTTP_V2::BufferedIo (or Net::BufferedIo) splits the event further
          # per `BUFSIZE = 1024 * 16`, hence if the size of the event exceeds the buffer size,
          # it will yield incomplete event data.
          # Ref: https://github.com/ruby/net-protocol/blob/master/lib/net/protocol.rb#L214
          buffer = ""

          response = Gitlab::HTTP.post(
            "#{base_url}#{CHAT_V2_ENDPOINT}",
            headers: Gitlab::AiGateway.headers(user: user, service: service),
            body: params.to_json,
            timeout: DEFAULT_TIMEOUT,
            allow_local_requests: true,
            stream_body: true
          ) do |fragment|
            log_conditional_info(user, message: "Received a chunk from v2/chat/agent", event_name: 'chunk_received',
              ai_component: 'duo_chat', fragment: fragment)

            buffer += fragment
            events = buffer.scan(EVENT_REGEX).flatten

            next if events.empty?

            events.each do |e|
              buffer.sub!(e, "")

              yield e if block_given?
            end
          end

          if response.success?
            log_info(
              message: "Finished streaming from v2/chat/agent", event_name: 'streaming_finished',
              ai_component: 'duo_chat')
            return
          end

          # Requests could fail at intermediate servers between GitLab-Sidekiq and AI Gateway.
          # Here are the list of servers that could intervene:
          # - Cloud Connector Cloud Flare
          # - GCP Cloud Run ingress / autoscaler
          # See https://gitlab.com/groups/gitlab-org/-/epics/15402 for more information.
          log_error(message: "Failed to request to v2/chat/agent",
            event_name: 'error_returned',
            ai_component: 'duo_chat',
            status: response.code,
            ai_response_server: response.headers['server'])

          # TODO: Improve error handling
          raise Gitlab::AiGateway::ForbiddenError if response.forbidden?
          raise Gitlab::AiGateway::ClientError if response.code >= 400 && response.code < 500
          raise Gitlab::AiGateway::ServerError if response.code >= 500

          raise ConnectionError, 'AI gateway not reachable'
        end

        def base_url
          feature_setting&.base_url || Gitlab::AiGateway.url
        end

        def service
          ::CloudConnector::AvailableServices.find_by_name(:duo_chat)
        end
        strong_memoize_attr :service
      end
    end
  end
end
