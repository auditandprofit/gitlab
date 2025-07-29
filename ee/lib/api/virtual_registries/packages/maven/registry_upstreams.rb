# frozen_string_literal: true

module API
  module VirtualRegistries
    module Packages
      module Maven
        class RegistryUpstreams < ::API::Base
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedSetup
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedAuthentication

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            delegate :upstream, to: :registry_upstream

            def target_group
              params[:id] ? registry_upstream.group : registry.group
            end

            def registry_upstream
              ::VirtualRegistries::Packages::Maven::RegistryUpstream.find(params[:id])
            end
            strong_memoize_attr :registry_upstream

            def registry
              ::VirtualRegistries::Packages::Maven::Registry.find(params[:registry_id])
            end
            strong_memoize_attr :registry
          end

          namespace 'virtual_registries/packages/maven' do
            namespace :registry_upstreams do
              desc 'Associates an upstream with a registry' do
                detail 'This feature was introduced in GitLab 18.1. \
                  This feature is currently in experiment state. \
                  This feature behind the `maven_virtual_registry` feature flag.'
                success code: 201, model: Entities::VirtualRegistries::Packages::Maven::RegistryUpstream
                failure [
                  { code: 400, message: 'Bad Request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end

              params do
                with(type: Integer, allow_blank: false) do
                  requires :registry_id, desc: 'The ID of the maven registry'
                  requires :upstream_id, desc: 'The ID of the maven upstream'
                end
              end

              post do
                authorize! :create_virtual_registry, registry

                if ::VirtualRegistries::Packages::Maven::Upstream.for_id_and_group(id: params[:upstream_id],
                  group: registry.group).none?
                  not_found!('Upstream')
                end

                registry_upstream = ::VirtualRegistries::Packages::Maven::RegistryUpstream.new(declared_params)
                render_validation_error!(registry_upstream) unless registry_upstream.save

                present registry_upstream, with: Entities::VirtualRegistries::Packages::Maven::RegistryUpstream
              end

              route_param :id, type: Integer, desc: 'The ID of the maven virtual registry upstream' do
                desc 'Update an upstream within a specific maven virtual registry' do
                  detail 'This feature was introduced in GitLab 18.0. \
                      This feature is currently in experiment state. \
                      This feature behind the `maven_virtual_registry` feature flag.'
                  success code: 200
                  failure [
                    { code: 400, message: 'Bad Request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                  tags %w[maven_virtual_registries]
                  hidden true
                end
                params do
                  requires :position, type: Integer, values: 1..20,
                    desc: 'The priority order of an upstream within a maven virtual registry'
                end

                patch do
                  authorize! :update_virtual_registry, upstream

                  registry_upstream.update_position(params[:position])

                  status :ok
                end

                desc 'Disassociates an upstream from a registry' do
                  detail 'This feature was introduced in GitLab 18.1. \
                  This feature is currently in experiment state. \
                  This feature behind the `maven_virtual_registry` feature flag.'
                  success code: 204
                  failure [
                    { code: 400, message: 'Bad Request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                  tags %w[maven_virtual_registries]
                  hidden true
                end

                delete do
                  authorize! :destroy_virtual_registry, upstream

                  destroy_conditionally!(registry_upstream) do
                    registry_upstream.transaction do
                      registry_upstream.sync_higher_positions
                      upstream.registry_upstreams.one? ? upstream.destroy : registry_upstream.destroy
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
