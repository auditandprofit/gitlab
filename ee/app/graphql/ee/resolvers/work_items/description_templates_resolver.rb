# frozen_string_literal: true

module EE
  module Resolvers
    module WorkItems
      module DescriptionTemplatesResolver
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        private

        override :fetch_root_templates_project
        def fetch_root_templates_project(namespace)
          return super unless namespace.is_a?(::Group) && !namespace.file_template_project_id

          namespace.ancestors(hierarchy_order: :asc).with_custom_file_templates.first&.checked_file_template_project
        end
      end
    end
  end
end
