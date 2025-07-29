# frozen_string_literal: true

module Geo
  module Console
    class TroubleshootReplicationOrVerificationForReplicatorClassMenu < MultipleChoiceForReplicatorMenu
      def name
        "Troubleshoot replication or verification for #{@replicator_class.replicable_title}"
      end

      def choices
        choices_on_any_site + choices_only_on_secondary_sites
      end

      private

      def choices_on_any_site
        [
          ShowPrimaryChecksumFailuresForReplicatorClassAction.new(
            output_stream: @output_stream, referer: self, replicator_class: @replicator_class)
        ]
      end

      def choices_only_on_secondary_sites
        return [] unless Gitlab::Geo.secondary?

        [
          ShowSyncFailuresForReplicatorClassAction.new(
            output_stream: @output_stream, referer: self, replicator_class: @replicator_class),
          ShowVerificationFailuresForReplicatorClassAction.new(
            output_stream: @output_stream, referer: self, replicator_class: @replicator_class)
        ]
      end
    end
  end
end
