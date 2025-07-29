# frozen_string_literal: true

module EE
  module ProtectedBranches # rubocop:disable Gitlab/BoundedContexts -- TODO: Namespacing
    class BasePolicyCheck
      def self.check!(...)
        new(...).check!
      end

      def initialize(protected_branch, params)
        @protected_branch = protected_branch
        @params = params
      end

      def check!
        raise ::Gitlab::Access::AccessDeniedError if violated?
      end

      def violated?
        raise NotImplementedError
      end

      private

      attr_reader :protected_branch, :params
    end
  end
end
