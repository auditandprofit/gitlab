# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class Upstream < ApplicationRecord
        belongs_to :group
        has_many :registry_upstreams,
          class_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream',
          inverse_of: :upstream,
          autosave: true
        has_many :registries, class_name: 'VirtualRegistries::Packages::Maven::Registry', through: :registry_upstreams
        has_many :cache_entries,
          class_name: 'VirtualRegistries::Packages::Maven::Cache::Entry',
          inverse_of: :upstream

        encrypts :username, :password

        validates :group, top_level_group: true, presence: true
        validates :url,
          addressable_url: {
            allow_localhost: false,
            allow_local_network: false,
            dns_rebind_protection: true,
            enforce_sanitization: true
          },
          presence: true
        validates :username, presence: true, if: :password?
        validates :password, presence: true, if: :username?
        validates :url, length: { maximum: 255 }
        validates :username, :password, length: { maximum: 510 }
        validates :cache_validity_hours, numericality: { greater_than_or_equal_to: 0, only_integer: true }
        validates :name, presence: true, length: { maximum: 255 }
        validates :description, length: { maximum: 1024 }

        before_validation :set_cache_validity_hours_for_maven_central, if: :url?, on: :create
        after_validation :reset_credentials, if: -> { persisted? && url_changed? }

        prevent_from_serialization(:password) if respond_to?(:prevent_from_serialization)

        scope :eager_load_registry_upstream, ->(registry:) {
          eager_load(:registry_upstreams)
            .where(registry_upstreams: { registry: })
            .order('registry_upstreams.position ASC')
        }

        scope :for_group, ->(group) { where(group:) }
        scope :for_id_and_group, ->(id:, group:) { where(id:, group:) }

        def url_for(path)
          full_url = File.join(url, path)
          Addressable::URI.parse(full_url).to_s
        end

        def headers
          return {} unless username.present? && password.present?

          authorization = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)

          { Authorization: authorization }
        end

        def default_cache_entries
          cache_entries.default
        end

        def object_storage_key
          hash = Digest::SHA2.hexdigest(SecureRandom.uuid)
          Gitlab::HashedPath.new(
            'virtual_registries',
            'packages',
            'maven',
            group_id,
            'upstream',
            id,
            'cache',
            'entry',
            hash[0..1],
            hash[2..3],
            hash[4..],
            root_hash: group_id
          ).to_s
        end

        def purge_cache!
          ::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker.perform_async(id)
        end

        private

        def reset_credentials
          return if username_changed? && password_changed?

          self.username = nil
          self.password = nil
        end

        def set_cache_validity_hours_for_maven_central
          return unless url.start_with?('https://repo1.maven.org/maven2')

          self.cache_validity_hours = 0
        end
      end
    end
  end
end
