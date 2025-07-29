<script>
import {
  GlAlert,
  GlBadge,
  GlLink,
  GlPopover,
  GlSprintf,
  GlCollapse,
  GlIcon,
  GlButton,
  GlToggle,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import {
  STREAM_ITEMS_I18N,
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
  UPDATE_STREAM_MESSAGE,
} from '../../constants';

import groupAuditEventStreamingDestinationsUpdate from '../../graphql/mutations/update_group_streaming_destination.mutation.graphql';
import instanceAuditEventStreamingDestinationsUpdate from '../../graphql/mutations/update_instance_streaming_destination.mutation.graphql';
import externalAuditEventDestinationUpdate from '../../graphql/mutations/update_external_destination.mutation.graphql';
import instanceExternalAuditEventDestinationUpdate from '../../graphql/mutations/update_instance_external_destination.mutation.graphql';
import googleCloudLoggingConfigurationUpdate from '../../graphql/mutations/update_gcp_logging_destination.mutation.graphql';
import instanceGoogleCloudLoggingConfigurationUpdate from '../../graphql/mutations/update_instance_gcp_logging_destination.mutation.graphql';
import amazonS3ConfigurationUpdate from '../../graphql/mutations/update_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationUpdate from '../../graphql/mutations/update_instance_amazon_s3_destination.mutation.graphql';

import StreamDestinationEditor from './stream_destination_editor.vue';
import StreamHttpDestinationEditor from './stream_http_destination_editor.vue';
import StreamGcpLoggingDestinationEditor from './stream_gcp_logging_destination_editor.vue';
import StreamAmazonS3DestinationEditor from './stream_amazon_s3_destination_editor.vue';

export default {
  components: {
    GlAlert,
    GlBadge,
    GlLink,
    GlPopover,
    GlSprintf,
    GlCollapse,
    GlButton,
    GlIcon,
    GlToggle,
    StreamDestinationEditor,
    StreamHttpDestinationEditor,
    StreamGcpLoggingDestinationEditor,
    StreamAmazonS3DestinationEditor,
  },
  directives: {
    GlTooltip,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isEditing: false,
      successMessage: null,
      isUpdatingActive: false,
      destinationActive: this.item.active !== false,
    };
  },
  computed: {
    isItemFiltered() {
      return Boolean(this.item?.eventTypeFilters?.length) || Boolean(this.item?.namespaceFilter);
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationTitle() {
      return this.item.name;
    },
    filterTooltipLink() {
      if (this.isInstance) {
        return this.$options.i18n.FILTER_TOOLTIP_ADMIN_LINK;
      }
      return this.$options.i18n.FILTER_TOOLTIP_GROUP_LINK;
    },
    activeToggleLabel() {
      return this.destinationActive ? __('Active') : __('Inactive');
    },
  },
  watch: {
    'item.active': {
      handler(newVal) {
        this.destinationActive = newVal !== false;
      },
      immediate: true,
    },
  },
  methods: {
    toggleEditMode() {
      this.isEditing = !this.isEditing;

      if (!this.isEditing) {
        this.clearSuccessMessage();
      }
    },
    onUpdated() {
      this.successMessage = UPDATE_STREAM_MESSAGE;
      this.$emit('updated');
    },
    onDelete($event) {
      this.$emit('deleted', $event);
    },
    onEditorError() {
      this.clearSuccessMessage();
      this.$emit('error');
    },
    clearSuccessMessage() {
      this.successMessage = null;
    },
    async toggleActive(newActiveState) {
      this.isUpdatingActive = true;

      try {
        await this.updateDestinationActive(newActiveState);
        this.handleToggleSuccess(newActiveState);
      } catch (error) {
        this.handleToggleError(error, newActiveState);
      } finally {
        this.isUpdatingActive = false;
      }
    },
    async updateDestinationActive(newActiveState) {
      if (this.glFeatures.useConsolidatedAuditEventStreamDestApi) {
        await this.toggleActiveConsolidatedApi(newActiveState);
      } else {
        await this.toggleActiveLegacyApi(newActiveState);
      }
    },
    handleToggleSuccess(newActiveState) {
      this.destinationActive = newActiveState;
      this.successMessage = newActiveState
        ? __('Destination activated successfully.')
        : __('Destination deactivated successfully.');
      this.$emit('updated');
    },
    handleToggleError(error, newActiveState) {
      Sentry.captureException(error);
      createAlert({
        message: __('Failed to update destination status. Please try again.'),
        captureError: true,
        error,
      });
      this.destinationActive = !newActiveState;
    },
    async executeMutation(mutation, variables, resultPath) {
      const { data } = await this.$apollo.mutate({
        mutation,
        variables,
      });

      const result = data[resultPath];

      if (result.errors?.length) {
        throw new Error(result.errors.join(', '));
      }
    },
    async toggleActiveConsolidatedApi(newActiveState) {
      const mutation = this.isInstance
        ? instanceAuditEventStreamingDestinationsUpdate
        : groupAuditEventStreamingDestinationsUpdate;

      const resultPath = this.isInstance
        ? 'instanceAuditEventStreamingDestinationsUpdate'
        : 'groupAuditEventStreamingDestinationsUpdate';

      const variables = {
        input: {
          id: this.item.id,
          name: this.item.name,
          config: {
            ...this.item.config,
          },
          active: newActiveState,
        },
      };

      await this.executeMutation(mutation, variables, resultPath);
    },
    async toggleActiveLegacyApi(newActiveState) {
      const { mutation, variables, resultPath } = this.buildLegacyMutationConfig(newActiveState);
      await this.executeMutation(mutation, variables, resultPath);
    },
    buildTypeSpecificVariables(baseVariables) {
      const typeVariables = {
        [DESTINATION_TYPE_HTTP]: {},
        [DESTINATION_TYPE_AMAZON_S3]: {
          fullPath: this.groupPath,
          accessKeyXid: this.item.accessKeyXid || this.item.config?.accessKeyXid,
          awsRegion: this.item.awsRegion || this.item.config?.awsRegion,
          bucketName: this.item.bucketName || this.item.config?.bucketName,
        },
        [DESTINATION_TYPE_GCP_LOGGING]: {
          googleProjectIdName:
            this.item.googleProjectIdName || this.item.config?.googleProjectIdName,
          clientEmail: this.item.clientEmail || this.item.config?.clientEmail,
          logIdName: this.item.logIdName || this.item.config?.logIdName || 'audit_events',
        },
      };

      return { ...baseVariables, ...typeVariables[this.type] };
    },
    getMutationConfig(type, isInstance) {
      const mutations = {
        [DESTINATION_TYPE_HTTP]: [
          externalAuditEventDestinationUpdate,
          instanceExternalAuditEventDestinationUpdate,
        ],
        [DESTINATION_TYPE_AMAZON_S3]: [
          amazonS3ConfigurationUpdate,
          instanceAmazonS3ConfigurationUpdate,
        ],
        [DESTINATION_TYPE_GCP_LOGGING]: [
          googleCloudLoggingConfigurationUpdate,
          instanceGoogleCloudLoggingConfigurationUpdate,
        ],
      };

      const resultPaths = {
        [DESTINATION_TYPE_HTTP]: [
          'externalAuditEventDestinationUpdate',
          'instanceExternalAuditEventDestinationUpdate',
        ],
        [DESTINATION_TYPE_AMAZON_S3]: [
          'auditEventsAmazonS3ConfigurationUpdate',
          'auditEventsInstanceAmazonS3ConfigurationUpdate',
        ],
        [DESTINATION_TYPE_GCP_LOGGING]: [
          'auditEventsGoogleCloudLoggingConfigurationUpdate',
          'instanceGoogleCloudLoggingConfigurationUpdate',
        ],
      };

      const index = isInstance ? 1 : 0;
      return {
        mutation: mutations[type][index],
        resultPath: resultPaths[type][index],
      };
    },
    buildLegacyMutationConfig(newActiveState) {
      const baseVariables = {
        id: this.item.id,
        name: this.item.name,
        active: newActiveState,
      };

      const { mutation, resultPath } = this.getMutationConfig(this.type, this.isInstance);

      if (!mutation) {
        throw new Error(`Unknown destination type: ${this.type}`);
      }

      return {
        mutation,
        variables: this.buildTypeSpecificVariables(baseVariables),
        resultPath,
      };
    },
  },
  i18n: { ...STREAM_ITEMS_I18N },
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <li class="list-item py-0">
    <div class="gl-flex gl-items-center gl-justify-between gl-py-6">
      <gl-button
        variant="link"
        class="gl-min-w-0 gl-font-bold !gl-text-default"
        :class="{ 'gl-opacity-60': !destinationActive }"
        :aria-expanded="isEditing"
        :aria-disabled="!destinationActive || isUpdatingActive"
        :disabled="isUpdatingActive"
        data-testid="toggle-btn"
        @click="toggleEditMode"
      >
        <gl-icon
          name="chevron-right"
          class="gl-transition-all"
          :class="{ 'gl-rotate-90': isEditing }"
        /><span class="gl-ml-2 gl-text-lg">{{ destinationTitle }}</span>
      </gl-button>

      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-toggle
          :value="destinationActive"
          :label="activeToggleLabel"
          :is-loading="isUpdatingActive"
          :disabled="isUpdatingActive"
          label-position="left"
          data-testid="destination-active-toggle"
          @change="toggleActive"
        />

        <template v-if="isItemFiltered">
          <gl-popover :target="item.id" data-testid="filter-popover">
            <gl-sprintf :message="$options.i18n.FILTER_TOOLTIP_LABEL">
              <template #link="{ content }">
                <gl-link :href="filterTooltipLink" target="_blank">
                  {{ content }}
                </gl-link>
              </template>
            </gl-sprintf>
          </gl-popover>
          <gl-badge :id="item.id" icon="filter" variant="neutral" data-testid="filter-badge">
            {{ $options.i18n.FILTER_BADGE_LABEL }}
          </gl-badge>
        </template>
      </div>
    </div>
    <gl-collapse :visible="isEditing">
      <gl-alert
        v-if="successMessage"
        :dismissible="true"
        class="gl-mb-6 gl-ml-6"
        variant="success"
        @dismiss="clearSuccessMessage"
      >
        {{ successMessage }}
      </gl-alert>
      <stream-destination-editor
        v-if="glFeatures.useConsolidatedAuditEventStreamDestApi"
        :item="item"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
      <stream-http-destination-editor
        v-else-if="type == $options.DESTINATION_TYPE_HTTP"
        :item="item"
        class="gl-pb-5 gl-pl-6 gl-pr-0"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
      <stream-gcp-logging-destination-editor
        v-else-if="type == $options.DESTINATION_TYPE_GCP_LOGGING"
        :item="item"
        class="gl-pb-5 gl-pl-6 gl-pr-0"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
      <stream-amazon-s3-destination-editor
        v-else-if="type == $options.DESTINATION_TYPE_AMAZON_S3"
        :item="item"
        class="gl-pb-5 gl-pl-6 gl-pr-0"
        @updated="onUpdated"
        @deleted="onDelete"
        @error="onEditorError"
        @cancel="toggleEditMode"
      />
    </gl-collapse>
  </li>
</template>
