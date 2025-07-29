# frozen_string_literal: true

module EE
  module Types
    module WorkItems
      module Widgets
        module AwardEmojiType
          def award_emoji
            object.work_item.batch_load_emojis_for_collection
          end
        end
      end
    end
  end
end
