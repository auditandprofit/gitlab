# frozen_string_literal: true

class Geo::UploadRegistry < Geo::BaseRegistry
  include ::Geo::ReplicableRegistry
  include ::Geo::VerifiableRegistry

  extend ::Gitlab::Utils::Override

  MODEL_CLASS = ::Upload
  MODEL_FOREIGN_KEY = :file_id

  self.table_name = 'file_registry'

  belongs_to :upload, foreign_key: :file_id

  scope :fresh, -> { order(created_at: :desc) }

  def self.find_registry_differences(range)
    source =
      self::MODEL_CLASS.replicables_for_current_secondary(range)
          .pluck(self::MODEL_CLASS.arel_table[:id])

    tracked =
      self.model_id_in(range)
          .pluck(:file_id)

    untracked = source - tracked
    unused_tracked = tracked - source

    [untracked, unused_tracked]
  end

  def file
    upload&.path || (s_('Removed upload with id %{id}') % { id: file_id })
  end

  def project
    return upload.model if upload&.model.is_a?(Project)
  end
end
