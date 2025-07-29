# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class Duo
          DUO_PROVISION_SERVICES = [
            DuoExclusive,
            DuoSelfHosted,
            DuoCore
          ].freeze

          def execute
            error_messages = []
            add_on_purchases = []

            DUO_PROVISION_SERVICES.each do |service|
              result = service.new.execute

              if result.error?
                error_messages << result.message
              else
                add_on_purchase = result.payload&.dig(:add_on_purchase)
                add_on_purchases << add_on_purchase if add_on_purchase
              end
            end

            if error_messages.empty?
              ServiceResponse.success(
                message: 'Successfully processed Duo add-ons',
                payload: { add_on_purchases: add_on_purchases }
              )
            else
              ServiceResponse.error(
                message: "Error processing one or more Duo add-ons: #{error_messages.join(', ')}",
                payload: { add_on_purchases: add_on_purchases }
              )
            end
          end
        end
      end
    end
  end
end
