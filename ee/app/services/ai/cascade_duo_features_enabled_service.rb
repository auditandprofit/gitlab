# frozen_string_literal: true

module Ai
  class CascadeDuoFeaturesEnabledService
    def initialize(duo_features_enabled)
      @duo_features_enabled = duo_features_enabled
    end

    def cascade_for_group(group)
      update_subgroups(group)
      update_projects(group)
    end

    def cascade_for_instance
      ProjectSetting.each_batch(of: 25000) do |batch|
        batch.update_all(duo_features_enabled: @duo_features_enabled)
      end

      ::NamespaceSetting.each_batch(of: 25000) do |batch|
        batch.update_all(duo_features_enabled: @duo_features_enabled)
      end
    end

    private

    def update_subgroups(group)
      group.self_and_descendants.each_batch do |batch|
        namespace_ids = batch.pluck_primary_key
        ::NamespaceSetting.for_namespaces(namespace_ids)
          .update_all(duo_features_enabled: @duo_features_enabled)
      end
    end

    def update_projects(group)
      group.all_projects.each_batch do |batch|
        project_ids_to_update = batch.pluck_primary_key
        ProjectSetting.for_projects(project_ids_to_update)
          .update_all(duo_features_enabled: @duo_features_enabled)
      end
    end
  end
end
