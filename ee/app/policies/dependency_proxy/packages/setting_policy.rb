# frozen_string_literal: true

module DependencyProxy
  module Packages
    class SettingPolicy < BasePolicy
      delegate(:project) { @subject.project }

      overrides(:read_package)

      rule { project.packages_disabled }.policy do
        prevent :read_package
        prevent :admin_dependency_proxy_packages_settings
      end

      rule { ~project.private_project & project.guest }.policy do
        enable :read_package
      end

      rule { can?(:reporter_access) }.policy do
        enable :read_package
      end

      rule { project.read_package_registry_deploy_token }.policy do
        enable :read_package
      end

      rule { project.write_package_registry_deploy_token }.policy do
        enable :read_package
      end

      rule { project.ip_enforcement_prevents_access & ~admin & ~auditor }.policy do
        prevent :read_package
      end

      condition(:config_dependency_proxy_enabled) do
        ::Gitlab.config.dependency_proxy.enabled
      end

      condition(:config_packages_enabled) do
        ::Gitlab.config.packages.enabled
      end

      condition(:licensed_dependency_proxy_for_packages_available) do
        @subject.project.licensed_feature_available?(:dependency_proxy_for_packages)
      end

      rule { ~config_dependency_proxy_enabled }.policy do
        prevent :admin_dependency_proxy_packages_settings
      end

      rule { ~config_packages_enabled }.policy do
        prevent :admin_dependency_proxy_packages_settings
      end

      rule { ~licensed_dependency_proxy_for_packages_available }.policy do
        prevent :admin_dependency_proxy_packages_settings
      end

      rule { can?(:maintainer_access) }.policy do
        enable :admin_dependency_proxy_packages_settings
      end
    end
  end
end
