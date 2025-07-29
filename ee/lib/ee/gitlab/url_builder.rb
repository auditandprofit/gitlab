# frozen_string_literal: true

module EE
  module Gitlab
    module UrlBuilder
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :build
        def build(object, **options)
          case object.itself
          when ::Epic
            instance.group_epic_url(object.group, object, **options)
          when ::Boards::EpicBoard
            instance.group_epic_board_url(object.group, object, **options)
          when ::Iteration
            instance.iteration_url(object, **options)
          when ::Vulnerability
            instance.project_security_vulnerability_url(object.project, object, **options)
          when ::Vulnerabilities::RelatedIssuesDecorator
            instance.issue_url(object, **options)
          when WorkItem
            if object.epic_work_item? && object.project_id.nil?
              instance.group_epic_url(object.namespace, object, **options)
            else
              super
            end
          when ::ComplianceManagement::Projects::ComplianceViolation
            instance.project_security_compliance_violation_url(object.project, object, **options)
          else
            super
          end
        end

        override :note_url
        def note_url(note, **options)
          noteable = note.noteable

          if note.for_epic?
            instance.group_epic_url(noteable.group, noteable, anchor: dom_id(note), **options)
          elsif note.for_vulnerability?
            instance.project_security_vulnerability_url(noteable.project, noteable, anchor: dom_id(note), **options)
          elsif note.for_group_wiki?
            instance.group_wiki_page_url(note.noteable, anchor: dom_id(note), **options)
          elsif note.for_compliance_violation?
            instance.project_security_compliance_violation_url(
              noteable.project, noteable, anchor: dom_id(note), **options)
          else
            super
          end
        end

        override :wiki_url
        def wiki_url(wiki, **options)
          if wiki.container.is_a?(Group)
            options[:controller] = 'groups/wikis'
            options[:group_id] = wiki.container
          end

          super
        end
      end
    end
  end
end
