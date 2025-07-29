<script>
import { GlAlert, GlLink, GlModal, GlSprintf } from '@gitlab/ui';

import { __ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import productAnalyticsProjectSettingsUpdate from '../../../graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import { updateProjectSettingsApolloCache } from './utils';

const NULL_PROJECT_SETTINGS = {
  productAnalyticsConfiguratorConnectionString: null,
  productAnalyticsDataCollectorHost: null,
  cubeApiBaseUrl: null,
  cubeApiKey: null,
};

export default {
  name: 'ClearProjectSettingsModal',
  components: { GlAlert, GlLink, GlModal, GlSprintf },
  inject: ['analyticsSettingsPath', 'namespaceFullPath'],
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
      hasError: false,
    };
  },
  computed: {
    modalPrimaryAction() {
      return {
        text: __('Continue'),
        attributes: {
          variant: 'confirm',
          loading: this.isLoading,
        },
      };
    },
    modalCancelAction() {
      return {
        text: __('Cancel'),
        attributes: {
          disabled: this.isLoading,
        },
      };
    },
  },
  methods: {
    onCancelClearSettings() {
      this.$emit('hide');
    },
    async clearProductAnalyticsProjectSettings() {
      this.hasError = false;
      this.isLoading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: productAnalyticsProjectSettingsUpdate,
          variables: {
            fullPath: this.namespaceFullPath,
            ...NULL_PROJECT_SETTINGS,
          },
          update: (store) => {
            updateProjectSettingsApolloCache(store, this.namespaceFullPath, NULL_PROJECT_SETTINGS);
          },
        });

        const { errors } = data.productAnalyticsProjectSettingsUpdate;

        if (errors?.length) {
          this.hasError = true;
          return;
        }

        this.$emit('hide');
        this.$emit('cleared');
      } catch (error) {
        this.hasError = true;
        Sentry.captureException(error);
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    :action-primary="modalPrimaryAction"
    :action-cancel="modalCancelAction"
    data-testid="clear-project-level-settings-confirmation-modal"
    modal-id="clear-project-level-settings-confirmation-modal"
    :title="s__('ProductAnalytics|Reset existing project provider settings')"
    @primary="clearProductAnalyticsProjectSettings"
    @canceled="onCancelClearSettings"
  >
    <gl-alert
      v-if="hasError"
      :dismissible="false"
      variant="danger"
      class="gl-mb-5"
      data-testid="modal-error"
    >
      <gl-sprintf
        :message="
          s__(
            'Analytics|Failed to clear project-level settings. Please try again or %{linkStart}clear them manually%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="analyticsSettingsPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
    <slot></slot>
  </gl-modal>
</template>
