# frozen_string_literal: true

module Vulnerabilities
  class RepresentationInformation < ::SecApplicationRecord
    include ShaAttribute

    self.table_name = 'vulnerability_representation_information'
    self.primary_key = 'vulnerability_id'

    sha_attribute :resolved_in_commit_sha

    belongs_to :vulnerability
    belongs_to :project

    validates :vulnerability, presence: true
    validates :project, presence: true
  end
end
