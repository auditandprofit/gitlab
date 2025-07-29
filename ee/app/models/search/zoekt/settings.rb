# frozen_string_literal: true

module Search
  module Zoekt
    # Settings module that contains Zoekt-specific settings configuration.
    # This module serves as a single source of truth for all Zoekt settings,
    # their types, defaults, and human-readable labels.
    #
    # Settings defined here are automatically:
    # - Added to visible attributes in ApplicationSettingsHelper
    # - Used to generate form inputs in the admin interface
    # - Displayed in the InfoService output
    #
    # To add a new setting:
    # 1. Add it to the SETTINGS hash with appropriate configuration
    # 2. The setting will automatically appear in all relevant places
    module Settings
      DEFAULT_INDEXING_TIMEOUT = '30m'
      DEFAULT_ROLLOUT_RETRY_INTERVAL = '1d'
      DEFAULT_LOST_NODE_THRESHOLD = '12h'
      DEFAULT_MAXIMUM_FILES = 500_000
      DISABLED_VALUE = '0'
      DURATION_BASE_REGEX = %r{([1-9]\d*)([mhd])}
      DURATION_INTERVAL_REGEX = %r{\A(?:0|#{DURATION_BASE_REGEX})\z}
      DURATION_INTERVAL_DISABLED_NOT_ALLOWED_REGEX = %r{\A#{DURATION_BASE_REGEX}\z}

      SETTINGS = {
        zoekt_indexing_enabled: {
          type: :boolean,
          default: false,
          label: -> { _('Enable indexing') }
        },
        zoekt_search_enabled: {
          type: :boolean,
          default: false,
          label: -> { _('Enable searching') }
        },
        zoekt_indexing_paused: {
          type: :boolean,
          default: false,
          label: -> { _('Pause indexing') }
        },
        zoekt_auto_index_root_namespace: {
          type: :boolean,
          default: false,
          label: -> { _('Index root namespaces automatically') }
        },
        zoekt_cache_response: {
          type: :boolean,
          default: true,
          label: -> {
            format(_("Cache search results for %{label}"), label: ::Search::Zoekt::Cache.humanize_expires_in)
          }
        },
        zoekt_cpu_to_tasks_ratio: {
          type: :float,
          default: 1.0,
          label: -> { _('Indexing CPU to tasks multiplier') },
          input_type: :number_field,
          input_options: { step: 0.1 }
        },
        zoekt_indexing_parallelism: {
          type: :integer,
          default: 1,
          label: -> { _('Number of parallel processes per indexing task') },
          input_type: :number_field
        },
        zoekt_rollout_batch_size: {
          type: :integer,
          default: 32,
          label: -> { _('Number of namespaces per indexing rollout') },
          input_type: :number_field
        },
        zoekt_lost_node_threshold: {
          type: :text,
          default: DEFAULT_LOST_NODE_THRESHOLD,
          label: -> { _('Offline nodes automatically deleted after') },
          input_options: {
            placeholder: format(
              N_("Must be in the following format: `30m`, `2h`, or `1d`. Set to `%{val}` to disable."),
              val: DISABLED_VALUE)
          },
          input_type: :text_field
        },
        zoekt_indexing_timeout: {
          type: :text,
          default: DEFAULT_INDEXING_TIMEOUT,
          label: -> { _('Indexing timeout per project') },
          input_options: { placeholder: format(N_("Must be in the following format: `30m`, `2h`, or `1d`.")) },
          input_type: :text_field
        },
        zoekt_maximum_files: {
          type: :integer,
          default: DEFAULT_MAXIMUM_FILES,
          label: -> { _('Maximum number of files per project to be indexed') },
          input_type: :number_field
        },
        zoekt_rollout_retry_interval: {
          type: :text,
          default: DEFAULT_ROLLOUT_RETRY_INTERVAL,
          label: -> { _('Retry interval for failed namespaces') },
          input_options: {
            placeholder: format(
              N_("Must be in the following format: `30m`, `2h`, or `1d`. Set to `%{val}` for no retries."),
              val: DISABLED_VALUE)
          },
          input_type: :text_field
        }
      }.freeze

      def self.all_settings
        SETTINGS
      end

      def self.boolean_settings
        SETTINGS.select { |_, config| config[:type] == :boolean }
      end

      def self.input_settings
        type_values = %i[float integer text]
        SETTINGS.select { |_, config| type_values.include?(config[:type]) }
      end

      def self.parse_duration(setting_value, default_value, allow_disabled: true)
        return if setting_value.blank?
        return if setting_value == DISABLED_VALUE && allow_disabled

        regex = allow_disabled ? DURATION_INTERVAL_REGEX : DURATION_INTERVAL_DISABLED_NOT_ALLOWED_REGEX
        match = setting_value.match(regex)
        match ||= default_value.match(regex)

        value = match[1].to_i
        unit = match[2]
        case unit
        when 'm' then value.minute
        when 'h' then value.hour
        when 'd' then value.day
        end
      end

      def self.indexing_timeout
        parse_duration(ApplicationSetting.current&.zoekt_indexing_timeout, DEFAULT_INDEXING_TIMEOUT,
          allow_disabled: false)
      end

      def self.rollout_retry_interval
        parse_duration(ApplicationSetting.current&.zoekt_rollout_retry_interval, DEFAULT_ROLLOUT_RETRY_INTERVAL)
      end

      def self.lost_node_threshold
        parse_duration(ApplicationSetting.current&.zoekt_lost_node_threshold, DEFAULT_LOST_NODE_THRESHOLD)
      end
    end
  end
end
