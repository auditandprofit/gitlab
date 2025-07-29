# frozen_string_literal: true

module EE
  module Types
    module MergeRequests
      module DetailedMergeStatusEnum
        extend ActiveSupport::Concern

        prepended do
          value 'REQUESTED_CHANGES',
            value: :requested_changes,
            description: 'Indicates a reviewer has requested changes.'
        end
      end
    end
  end
end
