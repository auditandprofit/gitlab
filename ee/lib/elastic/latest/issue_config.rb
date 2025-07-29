# frozen_string_literal: true

module Elastic
  module Latest
    module IssueConfig
      # To obtain settings and mappings methods
      extend Elasticsearch::Model::Indexing::ClassMethods
      extend Elasticsearch::Model::Naming::ClassMethods

      def self.index_name
        [Gitlab::CurrentSettings.elasticsearch_prefix, Rails.env, 'issues'].join('-')
      end

      settings Elastic::Latest::Config.settings.to_hash.deep_merge(
        index: {
          number_of_shards: Elastic::AsJSON.new { Elastic::IndexSetting[index_name].number_of_shards },
          number_of_replicas: Elastic::AsJSON.new { Elastic::IndexSetting[index_name].number_of_replicas }
        }
      )

      mappings dynamic: 'strict' do
        indexes :type, type: :keyword

        indexes :id, type: :integer
        indexes :iid, type: :integer

        indexes :title, type: :text, index_options: 'positions', analyzer: :title_analyzer
        indexes :description, type: :text, index_options: 'positions', analyzer: :code_analyzer
        indexes :created_at, type: :date
        indexes :updated_at, type: :date
        indexes :state, type: :keyword
        indexes :project_id, type: :integer
        indexes :author_id, type: :integer
        indexes :confidential, type: :boolean
        indexes :hidden, type: :boolean
        indexes :archived, type: :boolean
        indexes :assignee_id, type: :integer

        indexes :visibility_level, type: :integer
        indexes :issues_access_level, type: :integer
        indexes :upvotes, type: :integer
        indexes :namespace_ancestry_ids, type: :keyword
        indexes :label_ids, type: :keyword
        indexes :hashed_root_namespace_id, type: :integer
        indexes :work_item_type_id, type: :integer
        indexes :routing, type: :keyword

        indexes :schema_version, type: :short
      end
    end
  end
end
