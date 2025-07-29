# frozen_string_literal: true

module Integrations
  class GitGuardian < Integration
    validates :token, presence: true, if: :activated?

    field :token,
      type: :password,
      title: 'API token',
      help: -> { s_('GitGuardian|Personal access token to authenticate calls to the GitGuardian API.') },
      non_empty_password_title: -> { s_('ProjectService|Enter new API token') },
      non_empty_password_help: -> { s_('ProjectService|Leave blank to use your current API token.') },
      placeholder: 'Fc6d9dcf3Ab...',
      required: true

    def self.title
      'GitGuardian'
    end

    def self.description
      s_('GitGuardian|Scan pushed document contents for policy breaks.')
    end

    def self.help
      docs_link = ActionController::Base.helpers.link_to(
        _('Learn more.'),
        Rails.application.routes.url_helpers.help_page_url('user/project/integrations/git_guardian.md'),
        target: '_blank',
        rel: 'noopener noreferrer'
      )

      safe_format(_('Scan pushed document contents for policy breaks. %{docs_link}'), docs_link: docs_link.html_safe) # rubocop:disable Rails/OutputSafety -- It is fine to call html_safe here
    end

    def self.to_param
      'git_guardian'
    end

    def self.supported_events
      []
    end

    def execute(blobs, repository_url)
      ::Gitlab::GitGuardian::Client.new(token).execute(blobs, repository_url) if activated?
    end

    def testable?
      false
    end
  end
end
