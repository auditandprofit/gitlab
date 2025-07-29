# frozen_string_literal: true

module Ai
  module Catalog
    class BuiltInTool
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveRecord::FixedItemsModel::Model
      include GlobalID::Identification
      include Ai::Catalog::BuiltInToolDefinitions

      attribute :id, :integer
      attribute :name, :string
      attribute :title, :string
      attribute :description, :string

      validates :id, :name, :title, :description, presence: true

      class << self
        def count
          all.size
        end
      end
    end
  end
end
