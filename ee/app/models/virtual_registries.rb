# frozen_string_literal: true

module VirtualRegistries
  PACKAGE_TYPES = %i[maven].freeze

  def self.registries_count_for(group, registry_type:)
    registry_class = "::VirtualRegistries::Packages::#{registry_type.to_s.classify}::Registry".safe_constantize
    return 0 unless registry_class

    registry_class.for_group(group).size
  end
end
