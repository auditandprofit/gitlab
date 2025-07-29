# frozen_string_literal: true

module Groups
  class VirtualRegistriesController < Groups::VirtualRegistries::BaseController
    before_action :verify_read_virtual_registry!

    feature_category :virtual_registry
    urgency :low

    def index
      @registry_types_with_counts = ::VirtualRegistries::PACKAGE_TYPES.index_with do |registry_type|
        ::VirtualRegistries.registries_count_for(@group, registry_type:)
      end
    end
  end
end
