# frozen_string_literal: true

module API
  module Admin
    module Search
      class Zoekt < ::API::Base
        MAX_RESULTS = 20

        feature_category :global_search
        urgency :low

        helpers do
          def ensure_zoekt_indexing_enabled!
            return if ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

            error!(
              'application setting zoekt_indexing_enabled is not enabled', 400
            )
          end
        end

        before do
          authenticated_as_admin!
        end

        namespace 'admin' do
          resources 'zoekt/projects/:project_id/index' do
            desc 'Triggers indexing for the specified project' do
              success ::API::Entities::Search::Zoekt::ProjectIndexSuccess
              failure [
                { code: 401, message: '401 Unauthorized' },
                { code: 403, message: '403 Forbidden' },
                { code: 404, message: '404 Not found' }
              ]
            end
            params do
              requires :project_id,
                type: Integer,
                desc: 'The id of the project you want to index'
            end
            put do
              ensure_zoekt_indexing_enabled!
              project = Project.find(params[:project_id])

              job_id = project.repository.async_update_zoekt_index

              present({ job_id: job_id }, with: ::API::Entities::Search::Zoekt::ProjectIndexSuccess)
            end
          end
          # TODO: at some point rename to zoekt/nodes
          # This change is part of https://gitlab.com/gitlab-org/gitlab/-/issues/424456
          resources 'zoekt/shards' do
            desc 'Get all the Zoekt nodes' do
              success ::API::Entities::Search::Zoekt::Node
              failure [
                { code: 401, message: '401 Unauthorized' },
                { code: 403, message: '403 Forbidden' },
                { code: 404, message: '404 Not found' }
              ]
            end
            get do
              present ::Search::Zoekt::Node.all, with: ::API::Entities::Search::Zoekt::Node
            end

            resources ':node_id/indexed_namespaces' do
              desc 'Get all the indexed namespaces for this node' do
                success ::API::Entities::Search::Zoekt::IndexedNamespace
                failure [
                  { code: 401, message: '401 Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: '404 Not found' }
                ]
              end
              params do
                requires :node_id,
                  type: Integer,
                  desc: 'The id of the Search::Zoekt::Node'
              end
              get do
                node = ::Search::Zoekt::Node.find(params[:node_id])
                indexed_namespaces = node.enabled_namespaces.recent.with_limit(MAX_RESULTS)

                present indexed_namespaces,
                  with: ::API::Entities::Search::Zoekt::IndexedNamespace, zoekt_node_id: node.id
              end

              resources ':namespace_id' do
                desc 'Add a namespace to a node for Zoekt indexing' do
                  success ::API::Entities::Search::Zoekt::IndexedNamespace
                  failure [
                    { code: 401, message: '401 Unauthorized' },
                    { code: 403, message: '403 Forbidden' },
                    { code: 404, message: '404 Not found' }
                  ]
                end
                params do
                  requires :node_id,
                    type: Integer,
                    desc: 'The id of the Search::Zoekt::Node'
                  requires :namespace_id,
                    type: Integer,
                    desc: 'The id of the namespace you want to index in this node'
                  optional :search,
                    type: Grape::API::Boolean,
                    desc: 'Whether or not an indexed namespace should be enabled for searching'
                end
                put do
                  ensure_zoekt_indexing_enabled!
                  node = ::Search::Zoekt::Node.find(params[:node_id]) if params[:node_id] > 0
                  namespace = Namespace.find(params[:namespace_id])
                  root_namespace = namespace.root_ancestor

                  search = params.fetch(:search, nil)

                  attributes = { root_namespace_id: root_namespace.id }
                  zoekt_enabled_namespace = ::Search::Zoekt::EnabledNamespace.create_or_find_by(attributes) # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only be called from this API
                  if !search.nil? && zoekt_enabled_namespace.search != search
                    zoekt_enabled_namespace.update(search: search)
                  end

                  if node
                    attributes = {
                      zoekt_node_id: node.id,
                      zoekt_enabled_namespace_id: zoekt_enabled_namespace.id,
                      namespace_id: zoekt_enabled_namespace.root_namespace_id
                    }
                    ::Search::Zoekt::Index.create_or_find_by(attributes) do |record| # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only be called from this API
                      record.state = ::Search::Zoekt::Index.states[:ready]
                      record.replica = ::Search::Zoekt::Replica.for_enabled_namespace!(zoekt_enabled_namespace)
                    end
                  end

                  present zoekt_enabled_namespace,
                    with: ::API::Entities::Search::Zoekt::IndexedNamespace, zoekt_node_id: node&.id
                end

                desc 'Remove a namespace from a node for Zoekt indexing' do
                  failure [
                    { code: 401, message: '401 Unauthorized' },
                    { code: 403, message: '403 Forbidden' },
                    { code: 404, message: '404 Not found' }
                  ]
                end
                params do
                  requires :node_id,
                    type: Integer,
                    desc: 'The id of the Search::Zoekt::Node'
                  requires :namespace_id,
                    type: Integer,
                    desc: 'The id of the namespace you want to remove from this node'
                end
                delete do
                  node = ::Search::Zoekt::Node.find(params[:node_id]) if params[:node_id] > 0
                  namespace = Namespace.find(params[:namespace_id])
                  zoekt_enabled_namespace = namespace.zoekt_enabled_namespace

                  if zoekt_enabled_namespace.present?
                    zoekt_indices = if node
                                      zoekt_enabled_namespace.indices.for_node(node)
                                    else
                                      zoekt_enabled_namespace.indices
                                    end

                    zoekt_indices.map(&:destroy!)

                    zoekt_enabled_namespace.destroy!
                  end

                  ''
                end
              end
            end
          end
        end
      end
    end
  end
end
