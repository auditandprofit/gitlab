# frozen_string_literal: true

module Analytics
  class DashboardPolicy < BasePolicy
    delegate { @subject.container }
  end
end
