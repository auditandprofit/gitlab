# frozen_string_literal: true

module EE
  module Clusters
    module AgentPolicy
      extend ActiveSupport::Concern

      prepended do
        include RemoteDevelopment::AgentPolicy
      end
    end
  end
end
