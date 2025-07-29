# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module RelateActions
        extend ActiveSupport::Concern
        include ::Gitlab::QuickActions::Dsl

        included do
          desc { _('Link items blocked by this item') }
          explanation do |target_issues|
            format(_("Set this %{work_item_type} as blocking %{target}."),
              work_item_type: work_item_type(quick_action_target), target: target_issues.to_sentence)
          end
          execution_message do |target_issues|
            format(_("Added %{target} as a linked item blocked by this %{work_item_type}."),
              work_item_type: work_item_type(quick_action_target), target: target_issues.to_sentence)
          end
          params '<#item | group/project#item | item URL>'
          types Issue
          condition { can_block_issues? }
          parse_params { |issues| format_params(issues) }
          command :blocks do |target_issues|
            create_links(target_issues, type: 'blocks')
          end

          desc { _('Link items blocking this item') }
          explanation do |target_issues|
            format(_("Set this %{work_item_type} as blocked by %{target}."),
              work_item_type: work_item_type(quick_action_target), target: target_issues.to_sentence)
          end
          execution_message do |target_issues|
            format(_("Added %{target} as a linked item blocking this %{work_item_type}."),
              work_item_type: work_item_type(quick_action_target), target: target_issues.to_sentence)
          end
          params '<#item | group/project#item | item URL>'
          types Issue
          condition { can_block_issues? }
          parse_params { |issues| format_params(issues) }
          command :blocked_by do |target_issues|
            create_links(target_issues, type: 'is_blocked_by')
          end
        end

        private

        def can_block_issues?
          License.feature_available?(:blocked_issues) && can_admin_link?
        end

        def work_item_type(work_item)
          work_item.work_item_type.name.downcase
        end
      end
    end
  end
end
