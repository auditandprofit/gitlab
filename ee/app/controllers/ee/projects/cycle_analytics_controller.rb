# frozen_string_literal: true

module EE
  module Projects
    module CycleAnalyticsController
      include ::Gitlab::Utils::StrongMemoize
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action do
          push_frontend_feature_flag(:vsa_stage_time_scatter_chart, project.group)
        end
      end

      override :value_stream
      def value_stream
        return super unless params[:value_stream_id]

        project.project_namespace.value_streams.find_by_id(params[:value_stream_id])
      end
      strong_memoize_attr :value_stream
    end
  end
end
