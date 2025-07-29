# frozen_string_literal: true

# This class represents a software license.
# For use in the License Management feature.
class SoftwareLicense < ApplicationRecord
  include Presentable

  TransactionInProgressError = Class.new(StandardError)
  ALL_LICENSE_NAMES_CACHE_KEY = [name, 'all_license_names'].freeze
  TRANSACTION_MESSAGE = "Sub-transactions are not allowed as there is already an open transaction."
  LICENSE_LIMIT = 1_000

  validates :name, presence: true, uniqueness: true
  validates :spdx_identifier, length: { maximum: 255 }

  scope :by_name, ->(names) { where(name: names) }
  scope :by_spdx, ->(spdx_identifier) { where(spdx_identifier: spdx_identifier) }
  scope :ordered, -> { order(:name) }
  scope :spdx, -> { where.not(spdx_identifier: nil) }
  scope :unknown, -> { where(spdx_identifier: nil) }
  scope :grouped_by_name, -> { group(:name) }
  scope :unreachable_limit, -> { limit(LICENSE_LIMIT) }

  class << self
    def pluck_names
      pluck(:name)
    end
  end

  def canonical_id
    spdx_identifier || name.downcase
  end
end
