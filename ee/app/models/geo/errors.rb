# frozen_string_literal: true

module Geo
  module Errors
    BaseError = Class.new(StandardError)
    class StatusTimeoutError < BaseError
      def message
        "Generating Geo node status is taking too long"
      end
    end
  end
end
