# frozen_string_literal: true

module Namespaces
  class CascadeDuoFeaturesEnabledWorker
    include ApplicationWorker
    extend ActiveSupport::Concern

    feature_category :ai_abstraction_layer

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    urgency :low
    data_consistency :delayed
    loggable_arguments 0
    worker_resource_boundary :memory

    def perform(*args)
      group_id = args[0]
      group = Group.find(group_id)
      duo_features_enabled = group.namespace_settings.duo_features_enabled

      ::Ai::CascadeDuoFeaturesEnabledService.new(duo_features_enabled).cascade_for_group(group)
    end
  end
end
