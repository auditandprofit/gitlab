# frozen_string_literal: true

module Sbom
  class ComponentVersionsFinder
    def initialize(object, component_name)
      @object = object
      @component_name = component_name
    end

    def execute
      if object.is_a?(Project)
        Sbom::ComponentVersion.by_project_and_component(object.id, component_name)
      elsif object.is_a?(Group)
        Sbom::ComponentVersion.by_group_and_component(object, component_name)
      else
        Sbom::ComponentVersion.none
      end
    end

    private

    attr_reader :object, :component_name
  end
end
