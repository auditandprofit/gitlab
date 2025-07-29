# frozen_string_literal: true

module EE
  module ProjectSetting
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      cascading_attr :duo_features_enabled, :spp_repository_pipeline_access, :model_prompt_cache_enabled

      belongs_to :push_rule

      scope :has_vulnerabilities, -> { where('has_vulnerabilities IS TRUE') }
      scope :duo_features_set, ->(setting) { where(duo_features_enabled: setting) }

      validates :mirror_branch_regex, absence: true, if: -> { project&.only_mirror_protected_branches? }
      validates :mirror_branch_regex, untrusted_regexp: true, length: { maximum: 255 }
      validates :product_analytics_instrumentation_key, length: { maximum: 255 }, allow_blank: true
      validates :product_analytics_configurator_connection_string,
        length: { maximum: 512 },
        addressable_url: { schemes: %w[http https], allow_localhost: true, allow_local_network: true },
        allow_blank: true
      validates :product_analytics_data_collector_host,
        length: { maximum: 255 },
        addressable_url: { schemes: %w[http https], allow_localhost: true, allow_local_network: true },
        allow_blank: true
      validates :cube_api_base_url,
        length: { maximum: 512 },
        addressable_url: { schemes: %w[http https], allow_localhost: true, allow_local_network: true },
        allow_blank: true
      validates :cube_api_key, length: { maximum: 255 }, allow_blank: true
      validates :duo_context_exclusion_settings, json_schema: { filename: 'duo_context_exclusion_settings' }

      validates :observability_alerts_enabled, inclusion: { in: [true, false] }

      validate :all_or_none_product_analytics_attributes_set

      def all_or_none_product_analytics_attributes_set
        attrs = [
          :encrypted_product_analytics_configurator_connection_string,
          :product_analytics_data_collector_host,
          :cube_api_base_url,
          :encrypted_cube_api_key
        ]

        return if attrs.all? { |attr| self[attr].present? } || attrs.all? { |attr| self[attr].blank? }

        errors.add(:data_sources_settings, 'must all be set or none should be set')
      end
    end

    def selective_code_owner_removals
      project.licensed_feature_available?(:merge_request_approvers) &&
        ComplianceManagement::MergeRequestApprovalSettings::Resolver
        .new(project.group, project: project)
        .selective_code_owner_removals
        .value
    end

    def has_confluence?
      super && !::Integrations::Confluence.blocked_by_settings?(log: true)
    end
  end
end
