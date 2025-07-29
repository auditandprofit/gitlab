# frozen_string_literal: true

class Geo::GroupWikiRepositoryRegistry < Geo::BaseRegistry
  include ::Geo::ReplicableRegistry
  include ::Geo::VerifiableRegistry

  MODEL_CLASS = ::GroupWikiRepository
  MODEL_FOREIGN_KEY = :group_wiki_repository_id

  belongs_to :group_wiki_repository, class_name: 'GroupWikiRepository'
end
