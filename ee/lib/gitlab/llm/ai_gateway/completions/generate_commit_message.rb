# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class GenerateCommitMessage < Base
          extend ::Gitlab::Utils::Override

          WORDS_LIMIT = 10000

          override :inputs
          def inputs
            { diff: resource.raw_diffs.to_a.map(&:diff).join("\n").truncate_words(WORDS_LIMIT) }
          end

          override :prompt_version
          def prompt_version
            '1.2.0'
          end

          override :root_namespace
          def root_namespace
            resource.target_project.try(:root_ancestor)
          end
        end
      end
    end
  end
end
