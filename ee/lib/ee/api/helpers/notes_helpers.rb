# frozen_string_literal: true

module EE
  module API
    module Helpers
      module NotesHelpers
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class_methods do
          extend ::Gitlab::Utils::Override

          override :noteable_types
          def noteable_types
            super.append(
              ::API::Helpers::NotesHelpers::NoteableType.new(::Epic, :portfolio_management),
              ::API::Helpers::NotesHelpers::NoteableType.new(::Vulnerability, :vulnerability_management),
              ::API::Helpers::NotesHelpers::NoteableType.new(::WikiPage::Meta, :wiki, 'wiki_pages', 'group')
            )
          end
        end

        override :add_parent_to_finder_params
        def add_parent_to_finder_params(finder_params, noteable_type, parent_type)
          noteable_name = noteable_type.name.underscore

          if noteable_name == 'epic' || (noteable_name == 'wiki_page/meta' && parent_type == 'group')
            finder_params[:group_id] = user_group.id
          else
            super
          end
        end

        # private projects can be found as long as user is a project member.
        # internal projects can be found by any authenticated user.
        def find_merge_request(merge_request_iid)
          params = finder_params_by_noteable_type_and_id(::MergeRequest, merge_request_iid)

          ::NotesFinder.new(current_user, params).target || not_found!(::MergeRequest)
        end
      end
    end
  end
end
