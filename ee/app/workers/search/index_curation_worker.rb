# frozen_string_literal: true

module Search
  class IndexCurationWorker
    include ApplicationWorker
    include Search::Worker
    include Gitlab::ExclusiveLeaseHelpers
    prepend ::Geo::SkipSecondary

    data_consistency :always

    # There is no onward scheduling and this cron handles work from across the
    # application, so there's no useful context to add.
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Worker will be deleted
    include ActionView::Helpers::NumberHelper

    idempotent!
    urgency :throttled

    def initialize(*); end

    def perform; end
  end
end
