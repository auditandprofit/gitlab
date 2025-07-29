# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixStringConfigHashesGroupStreamingDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :update_string_configs_hashes_group_streaming_destinations
          feature_category :audit_events
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            updates = build_updates(sub_batch.where("jsonb_typeof(config) = 'string'"))
            bulk_update(updates) if updates.any?
          end
        end

        private

        def build_updates(records)
          records
            .filter_map do |record|
              parsed_json = parse_string_config(record.config)
              parsed_json ? { id: record.id, config: parsed_json } : nil
            end
        end

        def parse_string_config(string_value)
          parsing_attempts = [
            -> { ::Gitlab::Json.parse(string_value) },
            -> { ::Gitlab::Json.parse(string_value.tr("'", '"')) }
          ]

          parsing_attempts.lazy.filter_map do |attempt|
            attempt.call
          rescue JSON::ParserError
            nil
          end.first
        end

        def bulk_update(updates)
          placeholders = updates.map.with_index do |_, i|
            "(#{connection.quote(updates[i][:id])}, #{connection.quote(updates[i][:config].to_json)})"
          end.join(', ')

          connection.execute(<<~SQL)
            UPDATE audit_events_group_external_streaming_destinations
            SET config = v.config::jsonb
            FROM (VALUES #{placeholders}) AS v(id, config)
            WHERE audit_events_group_external_streaming_destinations.id = v.id
          SQL
        end
      end
    end
  end
end
