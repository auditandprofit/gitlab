# frozen_string_literal: true

module EE
  module API
    module Entities
      class DependencyListExport < Grape::Entity
        include ::API::Helpers::RelatedResourcesHelpers

        expose :id
        expose :status_name, as: :status
        expose :finished?, as: :has_finished
        expose :export_type
        expose :send_email
        expose :expires_at

        expose :self do |export|
          expose_url api_v4_dependency_list_exports_path(export_id: export.id)
        end
        expose :download do |export|
          expose_url api_v4_dependency_list_exports_download_path(export_id: export.id)
        end
      end
    end
  end
end
