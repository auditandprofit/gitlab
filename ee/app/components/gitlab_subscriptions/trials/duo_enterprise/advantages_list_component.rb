# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class AdvantagesListComponent < ViewComponent::Base
        def call
          render(GitlabSubscriptions::TrialAdvantagesComponent.new) do |c|
            c.with_header do
              s_('DuoEnterpriseTrial|GitLab Duo Enterprise is your end-to-end AI ' \
                'partner for faster, more secure software development.')
            end

            c.with_advantages(advantages)

            c.with_footer do
              s_('DuoEnterpriseTrial|GitLab Duo Enterprise is only available for purchase for Ultimate customers.')
            end
          end
        end

        private

        def advantages
          [
            s_('DuoEnterpriseTrial|Stay on top of regulatory requirements with self-hosted model deployment'),
            s_('DuoEnterpriseTrial|Enhance security and remediate vulnerabilities efficiently'),
            s_('DuoEnterpriseTrial|Quickly remedy broken pipelines to deliver products faster'),
            s_('DuoEnterpriseTrial|Gain deeper insights into GitLab Duo usage patterns'),
            s_('DuoEnterpriseTrial|Maintain control and keep your data safe')
          ]
        end
      end
    end
  end
end
