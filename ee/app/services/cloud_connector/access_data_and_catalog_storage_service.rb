# frozen_string_literal: true

# AccessDataStorageService creates or updates the CloudConnector::Access record with the data we received
# from the CustomersDot application. By design, the DB table has one or zero rows.
module CloudConnector
  class AccessDataAndCatalogStorageService
    def initialize(data: nil, catalog: nil)
      @data = data
      @catalog = catalog
    end

    def execute
      record = CloudConnector::Access.last || CloudConnector::Access.new

      record.data = data if data
      record.catalog = catalog if catalog
      record.updated_at = Time.current

      if record.save
        ServiceResponse.success
      else
        error_message = record.errors.full_messages.join(", ")
        Gitlab::AppLogger.error("Cloud Connector Access data/catalog update failed: #{error_message}")

        ServiceResponse.error(message: error_message)
      end
    end

    private

    attr_reader :data, :catalog
  end
end
