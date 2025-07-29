# frozen_string_literal: true

class HotspotDuoChatDuringTrialExperiment < ApplicationExperiment
  control
  variant(:candidate)

  private

  def control_behavior; end
  def candidate_behavior; end
end
