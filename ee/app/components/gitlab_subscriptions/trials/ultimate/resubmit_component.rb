# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Ultimate
      class ResubmitComponent < ViewComponent::Base
        def initialize(**kwargs)
          @hidden_fields = kwargs[:hidden_fields]
          @submit_path = kwargs[:submit_path]
        end

        private

        attr_reader :hidden_fields, :submit_path
      end
    end
  end
end
