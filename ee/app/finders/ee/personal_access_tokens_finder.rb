# frozen_string_literal: true

module EE
  module PersonalAccessTokensFinder # rubocop:disable Gitlab/BoundedContexts -- Original class in core is not in a bounded context
    extend ::Gitlab::Utils::Override

    override :by_owner_type
    def by_owner_type(tokens)
      case params[:owner_type]
      when 'human'
        tokens.owner_is_human
      when 'service_account'
        tokens.owner_is_service_account
      else
        tokens
      end
    end
  end
end
