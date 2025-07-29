# frozen_string_literal: true

class ElasticDeleteProjectWorker
  include ApplicationWorker
  include Search::Worker

  data_consistency :always
  prepend ::Geo::SkipSecondary

  sidekiq_options retry: 2
  urgency :throttled
  idempotent!
  pause_control :advanced_search

  def perform(project_id, es_id, options = {})
    options = options.with_indifferent_access
    remove_project_document(project_id, es_id, options) if options.fetch(:delete_project, true)
    return if options.fetch(:project_only, false)

    remove_children_documents(project_id, es_id, options)
    # WorkItems have different routing that's why one more query is needed.
    ::Search::Elastic::DeleteWorker.perform_async(task: :delete_project_work_items, project_id: project_id)
    helper.remove_wikis_from_the_standalone_index(project_id, 'Project', options[:namespace_routing_id]) # Wikis have different routing that's why one more query is needed.
    IndexStatus.for_project(project_id).delete_all
  end

  private

  def indices
    # Some standalone indices may not be created yet if pending advanced search migrations exist
    # Exclude Epic as projects can not have epics
    # Exclude Wiki and WorkItem as both have a different routing structure
    # Project will be removed independently
    excluded_classes = [Epic, Wiki, Project, WorkItem, Vulnerability]

    standalone_indices = helper.standalone_indices_proxies(exclude_classes: excluded_classes).select do |klass|
      alias_name = helper.klass_to_alias_name(klass: klass)
      helper.index_exists?(index_name: alias_name)
    end

    [helper.target_name] + standalone_indices.map(&:index_name)
  end

  def remove_project_document(project_id, es_id, options)
    routing_id = find_root_ancestor_id(project_id, options[:namespace_routing_id])

    if routing_id
      helper.client.delete(index: Project.index_name, id: es_id, routing: "n_#{routing_id}")
    else
      helper.client.delete_by_query(
        index: Project.index_name,
        body: {
          query: {
            bool: {
              filter: [
                {
                  exists: {
                    field: '_routing'
                  }
                },
                {
                  term: {
                    _id: es_id
                  }
                }
              ]
            }
          }
        }
      )
    end
  rescue Elasticsearch::Transport::Transport::Errors::Conflict
    self.class.perform_in(1.minute, project_id, es_id, options)
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    # no-op
  end

  def find_root_ancestor_id(project_id, namespace_id)
    if namespace_id
      Namespace.find_by_id(namespace_id)&.root_ancestor&.id
    else
      Project.find_by_id(project_id)&.root_ancestor&.id
    end
  end

  def remove_children_documents(project_id, es_id, options)
    helper.client.delete_by_query({
      index: indices,
      routing: es_id,
      body: {
        query: {
          bool: {
            should: [
              {
                term: {
                  _id: es_id
                }
              },
              {
                term: {
                  project_id: project_id
                }
              },
              {
                term: {
                  # We never set `project_id` for commits instead they have a nested rid which is the project_id
                  "commit.rid" => project_id
                }
              },
              {
                term: {
                  "rid" => project_id
                }
              },
              {
                term: {
                  target_project_id: project_id # handle merge_request which previously did not store project_id and only stored target_project_id
                }
              }
            ]
          }
        }
      }
    })
  rescue Elasticsearch::Transport::Transport::Errors::Conflict
    self.class.perform_in(1.minute, project_id, es_id, options)
  end

  def helper
    @helper ||= Gitlab::Elastic::Helper.default
  end
end
