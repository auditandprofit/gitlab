# frozen_string_literal: true

module EE
  module API
    module Entities
      module Geo
        class PipelineRefs < Grape::Entity
          expose :pipeline_refs, documentation: { type: 'string', is_array: true, example: ['refs/pipelines/1'] }
        end
      end
    end
  end
end
