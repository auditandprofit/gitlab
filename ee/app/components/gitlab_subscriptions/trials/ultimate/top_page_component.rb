# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Ultimate
      class TopPageComponent < ViewComponent::Base
        delegate :page_title, to: :helpers
      end
    end
  end
end
