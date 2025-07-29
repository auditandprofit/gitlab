# frozen_string_literal: true

module WorkItems
  module Statuses
    class Finder
      attr_reader :namespace, :params

      def initialize(namespace, params = {})
        @namespace = namespace
        @params = params
      end

      def execute
        if params.key?('system_defined_status_identifier')
          find_system_defined_status_by_id
        elsif params.key?('custom_status_id')
          find_custom_status_by_id
        elsif params.key?('name')
          name = params['name']
          find_status_by_name(name) || find_status_without_quotes(name)
        end
      end

      private

      def find_system_defined_status_by_id
        ::WorkItems::Statuses::SystemDefined::Status
          .find_by(id: params['system_defined_status_identifier'].to_i) # rubocop: disable CodeReuse/ActiveRecord -- this is a fixed model
      end

      def find_custom_status_by_id
        ::WorkItems::Statuses::Custom::Status
          .in_namespace(namespace)
          .find_by_id(params['custom_status_id'])
      end

      def find_status_without_quotes(name)
        return unless name.include?('"')
        return unless name.start_with?('"') && name.end_with?('"') && name.length > 2

        # Remove only leading and trailing quotes, not quotes within the name and
        # avoid regexp usage and ReDoS attacks with this approach.
        find_status_by_name(name[1..-2])
      end

      def find_status_by_name(name)
        return if name.blank?

        if namespace&.custom_statuses&.exists?
          ::WorkItems::Statuses::Custom::Status.find_by_namespace_and_name(namespace, name)
        else
          ::WorkItems::Statuses::SystemDefined::Status.find_by_name(name)
        end
      end
    end
  end
end
