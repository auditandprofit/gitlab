# frozen_string_literal: true

module API
  module VirtualRegistries
    module Packages
      module Maven
        class Upstreams < ::API::Base
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedSetup
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedAuthentication
          include ::API::PaginationParams

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def target_group
              case route.origin
              when %r{groups/:id}
                group
              when %r{registries/:id}
                registry.group
              when %r{upstreams/:id}
                upstream.group
              end
            end

            def group
              find_group!(params[:id])
            end
            strong_memoize_attr :group

            def registry
              ::VirtualRegistries::Packages::Maven::Registry.find(params[:id])
            end
            strong_memoize_attr :registry

            def upstream
              ::VirtualRegistries::Packages::Maven::Upstream.find(params[:id])
            end
            strong_memoize_attr :upstream
          end

          resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
            params do
              requires :id, types: [String, Integer], desc: 'The group ID or full group path. Must be a top-level group'
              use :pagination
            end

            namespace ':id/-/virtual_registries/packages/maven/upstreams' do
              desc 'List all maven virtual registry upstreams for a group' do
                detail 'This feature was introduced in GitLab 18.3. \
                    This feature is currently in experiment state. \
                    This feature is behind the `maven_virtual_registry` feature flag.'
                success code: 200, model: Entities::VirtualRegistries::Packages::Maven::Upstream
                failure [
                  { code: 400, message: 'Bad Request' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
                tags %w[maven_virtual_registries]
                hidden true
              end
              get do
                bad_request!(_('only available on top-level groups.')) unless group.root?
                authorize! :read_virtual_registry, group.virtual_registry_policy_subject

                present paginate(::VirtualRegistries::Packages::Maven::Upstream.for_group(group)),
                  with: Entities::VirtualRegistries::Packages::Maven::Upstream
              end
            end
          end

          namespace 'virtual_registries/packages/maven' do
            namespace :registries do
              route_param :id, type: Integer, desc: 'The ID of the maven virtual registry' do
                namespace :upstreams do
                  desc 'List all maven virtual registry upstreams for a registry' do
                    detail 'This feature was introduced in GitLab 17.4. \
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
                  get do
                    authorize! :read_virtual_registry, registry

                    present ::VirtualRegistries::Packages::Maven::Upstream.eager_load_registry_upstream(registry:),
                      with: Entities::VirtualRegistries::Packages::Maven::Upstream,
                      with_registry_upstream: true, exclude_upstream_id: true
                  end

                  desc 'Add a maven virtual registry upstream' do
                    detail 'This feature was introduced in GitLab 17.4. \
                        This feature is currently in experiment state. \
                        This feature behind the `maven_virtual_registry` feature flag.'
                    success code: 201, model: ::API::Entities::VirtualRegistries::Packages::Maven::Upstream
                    failure [
                      { code: 400, message: 'Bad Request' },
                      { code: 401, message: 'Unauthorized' },
                      { code: 403, message: 'Forbidden' },
                      { code: 404, message: 'Not found' },
                      { code: 409, message: 'Conflict' }
                    ]
                    tags %w[maven_virtual_registries]
                    hidden true
                  end
                  params do
                    requires :url, type: String, desc: 'The URL of the maven virtual registry upstream',
                      allow_blank: false
                    requires :name, type: String, desc: 'The name of the maven virtual registry upstream',
                      allow_blank: false
                    optional :description, type: String, desc: 'The description of the maven virtual registry upstream'
                    optional :username, type: String, desc: 'The username of the maven virtual registry upstream'
                    optional :password, type: String, desc: 'The password of the maven virtual registry upstream'
                    optional :cache_validity_hours, type: Integer, desc: 'The cache validity in hours. Defaults to 24'
                    all_or_none_of :username, :password
                  end
                  post do
                    authorize! :create_virtual_registry, registry

                    new_upstream = registry.upstreams.create(
                      declared_params(include_missing: false).merge(group: registry.group)
                    )

                    render_validation_error!(new_upstream) unless new_upstream.persisted?

                    present new_upstream, with: Entities::VirtualRegistries::Packages::Maven::Upstream,
                      with_registry_upstream: true, exclude_upstream_id: true
                  end
                end
              end
            end

            namespace :upstreams do
              route_param :id, type: Integer, desc: 'The ID of the maven virtual registry upstream' do
                desc 'Get a specific maven virtual registry upstream' do
                  detail 'This feature was introduced in GitLab 17.4. \
                        This feature is currently in experiment state. \
                        This feature behind the `maven_virtual_registry` feature flag.'
                  success ::API::Entities::VirtualRegistries::Packages::Maven::Upstream
                  failure [
                    { code: 400, message: 'Bad Request' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                  tags %w[maven_virtual_registries]
                  hidden true
                end
                get do
                  authorize! :read_virtual_registry, upstream

                  present upstream, with: ::API::Entities::VirtualRegistries::Packages::Maven::Upstream,
                    with_registry_upstreams: true, exclude_upstream_id: true
                end

                desc 'Update a maven virtual registry upstream' do
                  detail 'This feature was introduced in GitLab 17.4. \
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
                  optional :name, type: String, desc: 'The name of the maven virtual registry upstream',
                    allow_blank: false
                  optional :description, type: String, desc: 'The description of the maven virtual registry upstream'
                  optional :url, type: String, desc: 'The URL of the maven virtual registry upstream',
                    allow_blank: false
                  optional :username, type: String, desc: 'The username of the maven virtual registry upstream'
                  optional :password, type: String, desc: 'The password of the maven virtual registry upstream'
                  optional :cache_validity_hours, type: Integer, desc: 'The validity of the cache in hours'

                  at_least_one_of :name, :description, :url, :username, :password, :cache_validity_hours
                end
                patch do
                  authorize! :update_virtual_registry, upstream

                  render_validation_error!(upstream) unless upstream.update(declared_params(include_missing: false))

                  status :ok
                end

                desc 'Delete a maven virtual registry upstream' do
                  detail 'This feature was introduced in GitLab 17.4. \
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

                  destroy_conditionally!(upstream) do
                    upstream.transaction do
                      ::VirtualRegistries::Packages::Maven::RegistryUpstream
                        .sync_higher_positions(upstream.registry_upstreams)
                      upstream.destroy
                    end
                  end
                end

                desc 'Purge cache for a maven virtual registry upstream' do
                  detail 'This feature was introduced in GitLab 18.2. \
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
                delete :cache do
                  authorize! :destroy_virtual_registry, upstream

                  destroy_conditionally!(upstream) { upstream.purge_cache! }
                end
              end
            end
          end
        end
      end
    end
  end
end
