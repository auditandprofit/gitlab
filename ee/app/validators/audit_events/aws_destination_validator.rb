# frozen_string_literal: true

module AuditEvents
  class AwsDestinationValidator < BaseDestinationValidator
    def validate(record)
      if record.is_a?(AuditEvents::ExternallyStreamable) && record.aws?
        validate_attribute_uniqueness(record, ["bucketName"], "aws")
      else
        record.errors.add(:base, _('AwsDestinationValidator validates only aws external audit event destinations.'))
      end
    end
  end
end
