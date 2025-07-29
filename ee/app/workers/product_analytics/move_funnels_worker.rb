# frozen_string_literal: true

module ProductAnalytics
  class MoveFunnelsWorker
    include ApplicationWorker
    include Analytics::ProductAnalytics::ConfiguratorUrlValidation

    data_consistency :sticky
    feature_category :product_analytics
    idempotent!

    def perform(project_id, previous_custom_project_id, new_custom_project_id)
      @project = Project.find_by_id(project_id)

      return unless ::Feature.enabled?(:product_analytics_features, @project)

      @previous_custom_project = Project.find_by_id(previous_custom_project_id)
      @new_custom_project = Project.find_by_id(new_custom_project_id)
      @payload = build_payload

      return if @payload[:funnels].empty?

      validate_url!(funnels_url)

      Gitlab::HTTP.post(
        funnels_url,
        allow_local_requests: allow_local_requests?,
        body: build_payload.to_json
      )
    end

    def build_payload
      {
        project_ids: ["gitlab_project_#{@project.id}"],
        funnels: funnels
      }
    end

    private

    def funnel_names_to_delete
      custom_project = @previous_custom_project || @project

      ::ProductAnalytics::Funnel.names_within_project_repository(custom_project)
    end

    def funnels_to_create
      custom_project = @new_custom_project || @project

      ::ProductAnalytics::Funnel.for_project(custom_project)
    end

    def funnels
      funnels_to_send = []

      funnel_names_to_delete.each do |funnel_name|
        funnels_to_send << {
          state: 'deleted',
          name: funnel_name
        }
      end

      funnels_to_create.each do |funnel|
        next unless funnel.valid?

        funnels_to_send << {
          state: 'created',
          name: funnel.name,
          schema: funnel.to_json
        }
      end

      funnels_to_send
    end

    def funnels_url
      URI.join(
        configurator_url(@project),
        '/funnel-schemas'
      )
    end
  end
end
