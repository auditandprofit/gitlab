# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class AdvantagesListComponent < ViewComponent::Base
        def call
          render(GitlabSubscriptions::TrialAdvantagesComponent.new) do |c|
            c.with_header do
              s_('DuoProTrial|GitLab Duo Pro is designed to make teams more efficient throughout the software ' \
                'development lifecycle with:')
            end

            c.with_advantages(advantages)

            c.with_footer do
              s_('DuoProTrial|GitLab Duo Pro is only available for purchase for Premium and Ultimate users.')
            end
          end
        end

        private

        def advantages
          [
            s_('DuoProTrial|Code completion and code generation with Code Suggestions'),
            s_('DuoProTrial|Test Generation'),
            s_('DuoProTrial|Code Refactoring'),
            s_('DuoProTrial|Code Explanation'),
            s_('DuoProTrial|Chat within the IDE'),
            s_('DuoProTrial|Organizational user controls')
          ]
        end
      end
    end
  end
end
