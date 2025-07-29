# frozen_string_literal: true

module Types
  module Projects
    # rubocop: disable Graphql/AuthorizeTypes -- parent handles auth
    class DuoContextExclusionSettingsType < BaseObject
      graphql_name 'DuoContextExclusionSettings'
      description 'Settings for Duo context exclusion rules'

      field :exclusion_rules,
        [String],
        null: true,
        description: 'List of rules for excluding files from Duo context.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
