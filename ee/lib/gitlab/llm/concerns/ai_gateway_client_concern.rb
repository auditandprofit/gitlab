# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module AiGatewayClientConcern
        extend ActiveSupport::Concern
        include Gitlab::Utils::StrongMemoize

        # Subclasses must implement this method returning a Hash with all the needed input.
        # An `ArgumentError` can be emitted to signal an error extracting data from the `prompt_message`
        def inputs
          raise NotImplementedError
        end

        # Can be overridden by subclasses to specify the root namespace.
        # If not overridden, returns nil and namespace feature settings won't be used
        # Example: resource.try(:root_ancestor) for merge request related features
        def root_namespace
          nil
        end

        private

        def perform_ai_gateway_request!(user:, tracking_context: {})
          client = ::Gitlab::Llm::AiGateway::Client.new(
            user,
            service_name: service_name,
            tracking_context: tracking_context
          )

          response = client.complete_prompt(
            base_url: base_url_from_feature_setting,
            prompt_name: prompt_name,
            inputs: inputs,
            prompt_version: prompt_version_or_default,
            model_metadata: model_metadata
          )

          return unless response && response.body.present? && response.success?

          body = Gitlab::Json.parse(response.body)

          body.is_a?(String) ? body : body["content"]
        end

        def prompt_version_or_default
          is_self_hosted = feature_setting&.self_hosted? || false

          return prompt_version if prompt_version && (!is_self_hosted && !::Ai::AmazonQ.connected?)

          model_family = model_metadata&.dig(:name)
          ::Gitlab::Llm::PromptVersions.version_for_prompt(
            service_name,
            model_family
          )
        end

        def base_url_from_feature_setting
          selected_feature_setting&.base_url || ::Gitlab::AiGateway.url
        end

        def selected_feature_setting
          namespace_feature_setting || feature_setting
        end
        strong_memoize_attr(:selected_feature_setting)

        def namespace_feature_setting
          return unless root_namespace

          ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(root_namespace, service_name)
        end
        strong_memoize_attr(:namespace_feature_setting)

        def feature_setting
          ::Ai::FeatureSetting.find_by_feature(service_name)
        end
        strong_memoize_attr(:feature_setting)

        def model_metadata
          ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: selected_feature_setting).to_params
        end
        strong_memoize_attr(:model_metadata)

        # Must be overridden by subclasses to specify the service name.
        def service_name
          raise NotImplementedError
        end

        # Must be overridden by subclasses to specify the prompt name.
        def prompt_name
          raise NotImplementedError
        end

        # Can be overridden by subclasses to specify the prompt template version.
        # If not overridden or returns nil, prompt_version will be set to '^1.0.0'
        def prompt_version
          nil
        end
      end
    end
  end
end
