# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class WidgetPresenter < Gitlab::View::Presenter::Simple
      presents ::Namespace, as: :namespace

      def initialize(namespace, user:)
        super

        @widget_presenter = GitlabSubscriptions::Trials::StatusWidgetPresenter.new(namespace, user: user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
        @duo_enterprise_presenter = DuoEnterpriseStatusWidgetPresenter.new(namespace, user: user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
      end

      def attributes
        return {} unless eligible?

        presenter.attributes
      end

      private

      attr_reader :widget_presenter, :duo_enterprise_presenter

      def eligible?
        eligible_for_widget? && presenter.eligible_for_widget?
      end

      def presenter
        @presenter ||=
          if widget_presenter.eligible_for_widget?
            widget_presenter
          elsif duo_enterprise_presenter.eligible_for_widget?
            duo_enterprise_presenter
          else
            DuoProStatusWidgetPresenter.new(namespace, user: user) # rubocop:disable CodeReuse/Presenter -- we use it in this coordinator class
          end
      end

      def eligible_for_widget?
        namespace.present? &&
          ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          Ability.allowed?(user, :admin_namespace, namespace)
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/presenters/jh/gitlab_subscriptions/trials/widget_presenter.rb
GitlabSubscriptions::Trials::WidgetPresenter.prepend_mod
