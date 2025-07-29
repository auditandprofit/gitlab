<script>
import {
  GlAlert,
  GlEmptyState,
  GlLink,
  GlLoadingIcon,
  GlSkeletonLoader,
  GlSprintf,
} from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';
import { setUrlFragment, visitUrl } from '~/lib/utils/url_utility';

import initializeProductAnalyticsMutation from '../../../graphql/mutations/initialize_product_analytics.mutation.graphql';
import getProductAnalyticsProjectSettings from '../../../graphql/queries/get_product_analytics_project_settings.query.graphql';
import SelfManagedProviderCard from './self_managed_provider_card.vue';
import GitlabManagedProviderCard from './gitlab_managed_provider_card.vue';

export default {
  name: 'ProviderSelectionView',
  components: {
    GitlabManagedProviderCard,
    GlAlert,
    GlEmptyState,
    GlLink,
    GlLoadingIcon,
    GlSkeletonLoader,
    GlSprintf,
    SelfManagedProviderCard,
  },
  inject: {
    analyticsSettingsPath: {},
    canSelectGitlabManagedProvider: {},
    namespaceFullPath: {},
  },
  props: {
    loadingInstance: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isInitializingInstance: this.loadingInstance,
      instanceInitializingSvgPath: null,
      projectLevelAnalyticsProviderSettings: null,
      hasProjectSettingsError: false,
    };
  },
  computed: {
    projectAnalyticsSettingsPath() {
      return setUrlFragment(this.analyticsSettingsPath, '#js-analytics-data-sources');
    },
    isLoadingSettings() {
      return this.$apollo.queries.projectLevelAnalyticsProviderSettings.loading;
    },
    isOptionsHeaderVisible() {
      return this.canSelectGitlabManagedProvider && !this.hasProjectSettingsError;
    },
  },
  methods: {
    onConfirm(instanceInitializingSvgPath) {
      this.instanceInitializingSvgPath = instanceInitializingSvgPath;
      this.isInitializingInstance = true;
      this.initialize();
    },
    onError(err) {
      this.isInitializingInstance = false;
      this.$emit('error', err);
    },
    async initialize() {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: initializeProductAnalyticsMutation,
          variables: {
            projectPath: this.namespaceFullPath,
          },
        });

        const [error] = data?.projectInitializeProductAnalytics?.errors || [];

        if (error) {
          this.onError(new Error(error));
        } else {
          this.$emit('initialized');
        }
      } catch (err) {
        this.onError(err);
      }
    },
    openSettings() {
      visitUrl(this.projectAnalyticsSettingsPath, true);
    },
  },
  apollo: {
    projectLevelAnalyticsProviderSettings: {
      query: getProductAnalyticsProjectSettings,
      variables() {
        return {
          projectPath: this.namespaceFullPath,
        };
      },
      update(data) {
        this.hasProjectSettingsError = false;
        const { __typename, ...projectSettings } = data?.project?.productAnalyticsSettings || {};
        return projectSettings;
      },
      error() {
        this.hasProjectSettingsError = true;
      },
    },
  },
  docsPath: helpPagePath('development/internal_analytics/product_analytics', {
    anchor: 'onboard-a-gitlab-project',
  }),
};
</script>

<template>
  <section>
    <gl-empty-state
      v-if="isInitializingInstance"
      :title="s__('ProductAnalytics|Creating your product analytics instance…')"
      :svg-path="instanceInitializingSvgPath"
      :svg-height="null"
      data-testid="provider-selection-instance-loading"
    >
      <template #description>
        <p class="gl-max-w-80">
          {{
            s__(
              'ProductAnalytics|This might take a while, feel free to navigate away from this page and come back later.',
            )
          }}
        </p>
      </template>
      <template #actions>
        <gl-loading-icon size="lg" class="gl-mt-5" />
      </template>
    </gl-empty-state>
    <section v-else>
      <h1>{{ s__('ProductAnalytics|Analyze your product with Product Analytics') }}</h1>
      <p>
        <gl-sprintf
          :message="
            s__(
              `ProductAnalytics|Set up Product Analytics to track how your product is performing. Combine analytics with your GitLab data to better understand where you can improve your product and development processes. %{linkStart}Learn more%{linkEnd}.`,
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.docsPath" target="_blank" rel="noopener noreferrer">
              {{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </p>
      <h2 v-if="isOptionsHeaderVisible">{{ __('Select an option') }}</h2>
      <div class="gl-flex gl-flex-wrap gl-gap-5 md:gl-flex-nowrap">
        <template v-if="isLoadingSettings">
          <div class="gl-w-1/2">
            <gl-skeleton-loader data-testid="provider-card-skeleton-loader" />
          </div>
          <div v-if="canSelectGitlabManagedProvider" class="gl-w-1/2">
            <gl-skeleton-loader data-testid="provider-card-skeleton-loader" />
          </div>
        </template>

        <gl-alert
          v-else-if="hasProjectSettingsError"
          variant="danger"
          class="gl-w-full"
          data-testid="provider-settings-error-alert"
          >{{
            s__(
              'ProductAnalytics|An error occurred while fetching project settings. Refresh the page to try again.',
            )
          }}</gl-alert
        >

        <template v-else>
          <self-managed-provider-card
            :project-settings="projectLevelAnalyticsProviderSettings"
            @confirm="onConfirm"
            @open-settings="openSettings"
          />
          <gitlab-managed-provider-card
            v-if="canSelectGitlabManagedProvider"
            :project-settings="projectLevelAnalyticsProviderSettings"
            @confirm="onConfirm"
          />
        </template>
      </div>
    </section>
  </section>
</template>
