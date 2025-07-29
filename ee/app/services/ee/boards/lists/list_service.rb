# frozen_string_literal: true

module EE
  module Boards
    module Lists
      module ListService
        extend ::Gitlab::Utils::Override

        private

        override :licensed_list_types
        def licensed_list_types(board)
          super + licensed_lists_for(board)
        end

        def licensed_lists_for(board)
          parent = board.resource_parent

          List::LICENSED_LIST_TYPES.filter_map do |list_type|
            next if status_list_disabled?(list_type, parent)
            next unless parent&.feature_available?(:"board_#{list_type}_lists")

            ::List.list_types[list_type]
          end
        end

        def status_list_disabled?(list_type, parent)
          list_type == :status && ::Feature.disabled?(:work_item_status_feature_flag, parent&.root_ancestor)
        end
      end
    end
  end
end
