# frozen_string_literal: true

class ElasticIndexBulkCronWorker # rubocop:disable Scalability/IdempotentWorker
  include Elastic::BulkCronWorker

  worker_resource_boundary :cpu
  urgency :low
  data_consistency :sticky

  private

  def service
    Elastic::ProcessBookkeepingService.new
  end
end
