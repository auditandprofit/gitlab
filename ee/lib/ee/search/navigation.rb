# frozen_string_literal: true

module EE
  module Search
    module Navigation
      extend ::Gitlab::Utils::Override

      override :tabs
      def tabs
        (super || {}).tap do |nav|
          if ::Feature.enabled?(:work_item_scope_frontend, user)
            nav[:issues][:sub_items] ||= {}
            nav[:issues][:sub_items].merge!(get_epic_sub_item)
            next
          end

          nav[:epics] ||= {
            sort: 3,
            label: _("Epics"),
            condition: show_epics_search_tab?
          }
        end
      end

      private

      def get_epic_sub_item
        ::WorkItems::Type::TYPE_NAMES.each_with_object({}) do |(key, value, index), hash|
          next unless key.to_s == 'epic'

          hash[key] ||= {}
          hash[key][:scope] = 'epics'
          hash[key][:label] = value
          hash[key][:type] = key
          hash[key][:sort] = index
          hash[key][:active] = ''
          hash[key][:condition] = show_epics_search_tab?
        end
      end

      def zoekt_enabled?
        !!options[:zoekt_enabled]
      end

      override :show_code_search_tab?
      def show_code_search_tab?
        return true if super
        return false if project

        global_search_code_enabled =  ::Gitlab::CurrentSettings.global_search_code_enabled?
        global_search_zoekt_enabled = ::Feature.enabled?(:zoekt_cross_namespace_search, user, type: :ops)

        zoekt_enabled_for_user = zoekt_enabled? && ::Search::Zoekt.enabled_for_user?(user)

        if show_elasticsearch_tabs?
          return true if group

          return global_search_code_enabled
        elsif zoekt_enabled_for_user
          return ::Search::Zoekt.search?(group) if group.present?

          return global_search_code_enabled && global_search_zoekt_enabled
        end

        false
      end

      override :show_wiki_search_tab?
      def show_wiki_search_tab?
        return true if super
        return false if project
        return false unless show_elasticsearch_tabs?
        return true if group

        ::Gitlab::CurrentSettings.global_search_wiki_enabled?
      end

      def show_epics_search_tab?
        return false if project
        return false unless options[:show_epics]
        return true if group

        ::Gitlab::CurrentSettings.global_search_epics_enabled?
      end

      override :show_commits_search_tab?
      def show_commits_search_tab?
        return true if super # project search & user can search commits
        return false unless show_elasticsearch_tabs? # advanced search enabled
        return true if group # group search

        ::Gitlab::CurrentSettings.global_search_commits_enabled?
      end

      override :show_comments_search_tab?
      def show_comments_search_tab?
        return true if super

        project.nil? && show_elasticsearch_tabs?
      end

      def show_elasticsearch_tabs?
        !!options[:show_elasticsearch_tabs]
      end
    end
  end
end
