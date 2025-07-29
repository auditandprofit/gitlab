# frozen_string_literal: true

module Analytics
  class VisualizationPolicy < BasePolicy
    delegate { @subject.container }
  end
end
