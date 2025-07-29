# frozen_string_literal: true

module API
  module Concerns
    module VirtualRegistries
      module Packages
        module Maven
          module SharedAuthentication
            extend ActiveSupport::Concern
            include ::API::Helpers::Authentication

            included do
              authenticate_with do |accept|
                accept.token_types(:personal_access_token)
                  .sent_through(:http_private_token_header, :http_bearer_token, :private_token_param)
                accept.token_types(:job_token)
                  .sent_through(:http_job_token_header, :job_token_param)
                accept.token_types(:oauth_token)
                  .sent_through(:http_bearer_token, :access_token_param)
              end
            end
          end
        end
      end
    end
  end
end
