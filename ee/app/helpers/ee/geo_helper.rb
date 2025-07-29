# frozen_string_literal: true

module EE
  module GeoHelper
    STATUS_ICON_NAMES_BY_STATE = {
      synced: 'check-circle-filled',
      pending: 'status_pending',
      failed: 'status_failed',
      never: 'status_notfound'
    }.freeze

    def self.current_node_human_status
      return s_('Geo|primary') if ::Gitlab::Geo.primary?
      return s_('Geo|secondary') if ::Gitlab::Geo.secondary?

      s_('Geo|misconfigured')
    end

    def geo_sites_vue_data
      {
        replicable_types: replicable_types.to_json,
        new_site_url: new_admin_geo_node_path,
        geo_sites_empty_state_svg: image_path("illustrations/empty-state/empty-geo-md.svg")
      }
    end

    def selective_sync_types_json
      options = {
        ALL: {
          label: s_('Geo|All projects'),
          value: ''
        },
        NAMESPACES: {
          label: s_('Geo|Projects in certain groups'),
          value: 'namespaces'
        },
        SHARDS: {
          label: s_('Geo|Projects in certain storage shards'),
          value: 'shards'
        }
      }

      options.to_json
    end

    def replicable_types
      ::Gitlab::Geo::REPLICATOR_CLASSES.map do |replicator_class|
        replicable_class_data(replicator_class)
      end
    end

    def replicable_class_data(replicator_class)
      {
        data_type: replicator_class.data_type,
        data_type_title: replicator_class.data_type_title,
        data_type_sort_order: replicator_class.data_type_sort_order,
        title: replicator_class.replicable_title,
        title_plural: replicator_class.replicable_title_plural,
        name: replicator_class.replicable_name,
        name_plural: replicator_class.replicable_name_plural,
        graphql_field_name: replicator_class.graphql_field_name,
        graphql_registry_class: replicator_class.registry_class,
        graphql_mutation_registry_class: replicator_class.graphql_mutation_registry_class,
        replication_enabled: replicator_class.replication_enabled?,
        verification_enabled: replicator_class.verification_enabled?,
        graphql_registry_id_type: replicator_class.graphql_registry_id_type.to_s
      }
    end

    def enabled_replicator_classes
      replication_enabled_replicator_classes | verification_enabled_replicator_classes
    end

    def replication_enabled_replicator_classes
      ::Gitlab::Geo.replication_enabled_replicator_classes
    end

    def verification_enabled_replicator_classes
      ::Gitlab::Geo.verification_enabled_replicator_classes
    end

    def geo_filter_nav_options(replicable_controller, replicable_name)
      [
        {
          value: '',
          text: sprintf(s_('Geo|All %{replicable_name}'), { replicable_name: replicable_name }),
          href: url_for(
            controller: replicable_controller,
            replicable_name_plural: replicable_name)
        },
        {
          value: 'pending',
          text: s_('Geo|In progress'),
          href: url_for(
            controller: replicable_controller,
            replicable_name_plural: replicable_name,
            sync_status: 'pending')
        },
        {
          value: 'failed',
          text: s_('Geo|Failed'),
          href: url_for(
            controller: replicable_controller,
            replicable_name_plural: replicable_name,
            sync_status: 'failed')
        },
        {
          value: 'synced',
          text: s_('Geo|Synced'),
          href: url_for(
            controller: replicable_controller,
            replicable_name_plural: replicable_name,
            sync_status: 'synced')
        }
      ]
    end

    def format_file_size_for_checksum(file_size)
      return file_size if file_size.length.even?

      "0" + file_size
    end
  end
end
