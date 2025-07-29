# frozen_string_literal: true

module EE
  module RepositoryCheck
    module SingleRepositoryWorker
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :perform
      def perform(shard_name)
        return super unless ::Gitlab::Geo.secondary?
      end
    end
  end
end
