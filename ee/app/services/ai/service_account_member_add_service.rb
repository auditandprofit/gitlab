# frozen_string_literal: true

module Ai
  class ServiceAccountMemberAddService
    def initialize(project, service_account_user)
      @project = project
      @service_account_user = service_account_user
    end

    def execute
      existing_member = project.member(service_account_user)
      return ServiceResponse.success(message: "Membership already exists. Nothing to do.") if existing_member

      return ServiceResponse.error(message: "Service account user not found") unless service_account_user

      result = project.add_developer(service_account_user)
      return ServiceResponse.error(message: "Failed to add service account as developer") unless result.persisted?

      ServiceResponse.success(payload: result)
    end

    private

    attr_reader :project, :service_account_user
  end
end
