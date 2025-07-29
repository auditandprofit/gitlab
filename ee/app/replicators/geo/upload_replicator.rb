# frozen_string_literal: true

module Geo
  class UploadReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Upload
    end

    # @return [String] human-readable title of this replicator.
    def self.replicable_title
      s_('Geo|Upload')
    end

    # @return [String] human-readable title of this replicator, pluralized.
    def self.replicable_title_plural
      s_('Geo|Uploads')
    end

    def carrierwave_uploader
      model_record.retrieve_uploader
    end

    # Do not attempt download unless the upload's owner `model` is present.
    # Otherwise, attempting to build file paths will raise an exception.
    def predownload_validation_failure
      error_message = model_is_missing_error_message
      return error_message if error_message

      super
    end

    def calculate_checksum
      error_message = model_is_missing_error_message
      raise error_message if error_message

      super
    end

    def model_is_missing_error_message
      upload = model_record
      return if upload.model.present?

      "The model which owns this Upload is missing. Upload ID##{upload.id}, #{upload.model_type} ID##{upload.model_id}"
    end
  end
end
