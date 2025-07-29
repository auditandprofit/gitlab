# frozen_string_literal: true

module Sbom
  class ComponentsFinder
    def initialize(namespace, query = nil)
      @namespace = namespace
      @query = query
    end

    def execute
      Sbom::Component.by_namespace(namespace, query)
    end

    private

    attr_reader :namespace, :query
  end
end
