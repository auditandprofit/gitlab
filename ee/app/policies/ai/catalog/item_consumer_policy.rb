# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumerPolicy < ::BasePolicy
      delegate { @subject.project }
      delegate { @subject.group }
    end
  end
end
