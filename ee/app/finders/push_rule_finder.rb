# frozen_string_literal: true

class PushRuleFinder
  def execute
    global_rule
  end

  private

  def global_rule
    PushRule.find_by(is_sample: true) # rubocop: disable CodeReuse/ActiveRecord -- extracted for finder use
  end
end
