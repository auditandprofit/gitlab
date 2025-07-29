# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class TemplateCacheService
      def initialize
        @cache = {}
      end

      def fetch(scan_type, latest: false)
        (@cache[[scan_type.to_sym, latest]] ||= ci_configuration(scan_type, latest)).deep_dup
      end

      private

      def ci_configuration(scan_type, latest)
        Gitlab::Ci::Config.new(template_content(scan_type, latest)).to_hash
      end

      def template_content(scan_type, latest)
        template_finder(scan_type, latest).execute.content
      end

      def template_finder(scan_type, latest)
        ::TemplateFinder.build(:gitlab_ci_ymls, nil, name: CiAction::Template.scan_template_path(scan_type, latest))
      end
    end
  end
end
