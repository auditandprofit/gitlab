# frozen_string_literal: true

module Ai
  module DuoSettings
    class UpdateService
      def initialize(update_params)
        @params = update_params
      end

      def execute
        ai_settings = ::Ai::Setting.instance

        begin
          ai_settings.update!(params)

          ServiceResponse.success(payload: ai_settings)
        rescue StandardError => e
          ServiceResponse.error(message: e.record.errors.full_messages.join(", "))
        end
      end

      private

      attr_reader :params
    end
  end
end
