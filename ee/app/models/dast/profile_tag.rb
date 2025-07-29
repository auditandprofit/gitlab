# frozen_string_literal: true

module Dast
  class ProfileTag < ::SecApplicationRecord
    self.table_name = 'dast_profiles_tags'

    belongs_to :tag, class_name: 'Ci::Tag', optional: false
    belongs_to :dast_profile, class_name: 'Dast::Profile', optional: false
  end
end
