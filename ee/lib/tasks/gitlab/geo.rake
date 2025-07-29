# frozen_string_literal: true

namespace :gitlab do
  namespace :geo do
    desc "Gitlab | Geo | Check replication/verification status"
    task check_replication_verification_status: :environment do
      abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?
      abort GEO_LICENSE_ERROR_TEXT unless Gitlab::Geo.license_allows?

      current_node_status = GeoNodeStatus.current_node_status
      geo_node = current_node_status.geo_node

      unless geo_node.secondary?
        puts Rainbow('This command is only available on a secondary node').red
        exit
      end

      puts

      status_check = Gitlab::Geo::GeoNodeStatusCheck.new(current_node_status, geo_node)

      status_check.print_replication_verification_status
      complete = status_check.replication_verification_complete?

      if complete
        puts Rainbow('SUCCESS - Replication is up-to-date.').green
        exit 0
      else
        puts Rainbow("ERROR - Replication is not up-to-date. \n"\
        "Please see documentation to complete replication: "\
        "https://docs.gitlab.com/ee/administration/geo/disaster_recovery"\
        "/planned_failover.html#ensure-geo-replication-is-up-to-date")
               .red
        exit 1
      end
    end

    desc 'Gitlab | Geo | Prevent updates to primary site'
    task prevent_updates_to_primary_site: :environment do
      abort 'This command is only available on a primary node' unless ::Gitlab::Geo.primary?

      Gitlab::Geo::GeoTasks.enable_maintenance_mode
      Gitlab::Geo::GeoTasks.drain_non_geo_queues
    end

    desc 'Gitlab | Geo | Wait until replicated and verified'
    task wait_until_replicated_and_verified: :environment do
      abort 'This command is only available on a secondary node' unless ::Gitlab::Geo.secondary?

      Gitlab::Geo::GeoTasks.wait_until_replicated_and_verified
    end
  end
end
