# frozen_string_literal: true

module Analytics
  class PanelPolicy < BasePolicy
    delegate { @subject.container }
  end
end
