# frozen_string_literal: true

module Projects
  class AiFeatures
    attr_accessor :project

    def initialize(project)
      @project = project
    end

    def review_merge_request_allowed?(user)
      Ability.allowed?(user, :access_ai_review_mr, project) &&
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: project,
          feature_name: :review_merge_request,
          user: user
        ).allowed?
    end
  end
end
