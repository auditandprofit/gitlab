# frozen_string_literal: true

module Ai
  class VectorizableFile < ApplicationRecord
    self.table_name = "ai_vectorizable_files"

    mount_uploader :file, AttachmentUploader

    validates :project, presence: true

    validates :file,
      presence: true,
      file_size: { maximum: Gitlab::CurrentSettings.max_attachment_size.megabytes.to_i }

    validates :name,
      presence: true,
      length: { maximum: 255 }

    belongs_to :project
    has_many :attachments, class_name: 'Ai::AgentVersionAttachment', foreign_key: :ai_vectorizable_file_id,
      inverse_of: :file
    has_many :versions, through: :attachments, source: :version

    def uploads_sharding_key
      { project_id: project_id }
    end
  end
end
