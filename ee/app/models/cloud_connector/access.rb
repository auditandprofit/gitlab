# frozen_string_literal: true

module CloudConnector
  class Access < ApplicationRecord
    # Technically, access data has no expiration date, but we know that tokens
    # are good for at most 3 days currently, so this is a good estimate.
    STALE_PERIOD = 3.days

    self.table_name = 'cloud_connector_access'
    validates :data, json_schema: { filename: "cloud_connector_access" }, allow_nil: true
    validates :catalog, json_schema: { filename: "cloud_connector_access_catalog" }, allow_nil: true
    validate :data_or_catalog_present

    scope :with_data, -> { where.not(data: nil) }
    scope :with_catalog, -> { where.not(catalog: nil) }

    private

    def data_or_catalog_present
      return unless data.blank? && catalog.blank?

      errors.add(:base, "Either valid data or catalog must be present")
    end
  end
end
