# frozen_string_literal: true

module EE
  module API
    module Entities
      module SharedGroupWithGroup
        extend ActiveSupport::Concern

        prepended do
          include GroupLinksHelper

          expose :member_role_id, documentation: { type: 'integer', example: 12 }, if: ->(group_link, _) do
            custom_role_for_group_link_enabled?(group_link.shared_group)
          end
        end
      end
    end
  end
end
