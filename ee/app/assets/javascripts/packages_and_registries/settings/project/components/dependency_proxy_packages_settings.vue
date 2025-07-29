<script>
import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import SettingsSubSection from '~/vue_shared/components/settings/settings_sub_section.vue';
import getDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/queries/get_dependency_proxy_packages_settings.query.graphql';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';

export default {
  name: 'DependencyProxyPackagesSettings',
  components: {
    DependencyProxyPackagesSettingsForm,
    GlAlert,
    GlSkeletonLoader,
    SettingsSubSection,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  apollo: {
    dependencyProxyPackagesSettings: {
      query: getDependencyProxyPackagesSettings,
      context: {
        batchKey: 'PackageRegistryProjectSettings',
      },
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project?.dependencyProxyPackagesSetting || {},
      error(e) {
        this.fetchSettingsError = e;
        Sentry.captureException(e);
      },
    },
  },
  data() {
    return {
      dependencyProxyPackagesSettings: {},
      fetchSettingsError: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.dependencyProxyPackagesSettings.loading;
    },
  },
};
</script>

<template>
  <settings-sub-section
    :heading="s__('DependencyProxy|Dependency Proxy')"
    :description="
      s__(
        'DependencyProxy|Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
      )
    "
    data-testid="dependency-proxy-settings"
  >
    <gl-alert v-if="fetchSettingsError" variant="warning" :dismissible="false">
      {{
        s__('DependencyProxy|Something went wrong while fetching the dependency proxy settings.')
      }}
    </gl-alert>

    <gl-skeleton-loader v-else-if="isLoading" />
    <dependency-proxy-packages-settings-form v-else :data="dependencyProxyPackagesSettings" />
  </settings-sub-section>
</template>
