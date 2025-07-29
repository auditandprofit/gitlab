# frozen_string_literal: true

module EE
  module ProjectCiCdSetting
    extend ActiveSupport::Concern

    prepended do
      enum :restrict_pipeline_cancellation_role, {
        developer: 0,
        maintainer: 1,
        no_one: 2
      }, prefix: true
    end

    def merge_pipelines_enabled?
      project.feature_available?(:merge_pipelines) && super
    end

    def merge_trains_enabled?
      super &&
        merge_pipelines_enabled? &&
        project.feature_available?(:merge_trains)
    end

    def merge_pipelines_were_disabled?
      saved_change_to_attribute?(:merge_pipelines_enabled, from: true, to: false)
    end

    def auto_rollback_enabled?
      super && project.feature_available?(:auto_rollback)
    end

    def merge_trains_skip_train_allowed?
      merge_trains_skip_train_allowed &&
        merge_trains_enabled? &&
        !project.ff_merge_must_be_possible? && # Not yet supported, see https://gitlab.com/gitlab-org/gitlab/-/issues/429009
        ::Feature.enabled?(:merge_trains_skip_train, project)
    end
  end
end
