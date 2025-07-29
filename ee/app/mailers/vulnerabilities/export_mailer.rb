# frozen_string_literal: true

module Vulnerabilities
  class ExportMailer < ApplicationMailer
    helper ::EmailsHelper
    helper ::VulnerabilitiesHelper

    layout 'mailer'

    def completion_email(export)
      @export = export
      @expiration_days = Vulnerabilities::Export::EXPIRES_AFTER.in_days.to_i

      exportable = export.exportable

      group = case exportable
              when ::Project
                exportable.group
              when ::Group
                exportable
              end

      mail_with_locale(
        to: export.author.notification_email_for(group),
        subject: s_('Vulnerabilities|Vulnerability report export')
      )
    end
  end
end
