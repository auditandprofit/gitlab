<script>
import { GlModal, GlSprintf } from '@gitlab/ui';

import { __, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import deleteGroupStreamingDestinationsQuery from '../../graphql/mutations/delete_group_streaming_destination.mutation.graphql';
import deleteInstanceStreamingDestinationsQuery from '../../graphql/mutations/delete_instance_streaming_destination.mutation.graphql';
// Legacy Mutations 👇 To be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/523881
import deleteExternalDestination from '../../graphql/mutations/delete_external_destination.mutation.graphql';
import deleteInstanceExternalDestination from '../../graphql/mutations/delete_instance_external_destination.mutation.graphql';
import googleCloudLoggingConfigurationDestroy from '../../graphql/mutations/delete_gcp_logging_destination.mutation.graphql';
import instanceGoogleCloudLoggingConfigurationDestroy from '../../graphql/mutations/delete_instance_gcp_logging_destination.mutation.graphql';
import amazonS3ConfigurationDestroy from '../../graphql/mutations/delete_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationDestroy from '../../graphql/mutations/delete_instance_amazon_s3_destination.mutation.graphql';

import {
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_GCP_LOGGING,
  DESTINATION_TYPE_AMAZON_S3,
} from '../../constants';

export default {
  components: {
    GlModal,
    GlSprintf,
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
  computed: {
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationDestroyMutation() {
      if (this.glFeatures.useConsolidatedAuditEventStreamDestApi) {
        return this.isInstance
          ? deleteInstanceStreamingDestinationsQuery
          : deleteGroupStreamingDestinationsQuery;
      }

      switch (this.type) {
        case DESTINATION_TYPE_GCP_LOGGING:
          return this.isInstance
            ? instanceGoogleCloudLoggingConfigurationDestroy
            : googleCloudLoggingConfigurationDestroy;
        case DESTINATION_TYPE_AMAZON_S3:
          return this.isInstance
            ? instanceAmazonS3ConfigurationDestroy
            : amazonS3ConfigurationDestroy;
        case DESTINATION_TYPE_HTTP:
        default:
          return this.isInstance ? deleteInstanceExternalDestination : deleteExternalDestination;
      }
    },
    destinationTitle() {
      return this.item.name;
    },
  },
  methods: {
    destinationErrors(data) {
      if (this.glFeatures.useConsolidatedAuditEventStreamDestApi) {
        return this.isInstance
          ? data.instanceAuditEventStreamingDestinationsDelete.errors
          : data.groupAuditEventStreamingDestinationsDelete.errors;
      }

      switch (this.type) {
        case DESTINATION_TYPE_GCP_LOGGING:
          return this.isInstance
            ? data.instanceGoogleCloudLoggingConfigurationDestroy.errors
            : data.googleCloudLoggingConfigurationDestroy.errors;
        case DESTINATION_TYPE_AMAZON_S3:
          return this.isInstance
            ? data.auditEventsInstanceAmazonS3ConfigurationDelete.errors
            : data.auditEventsAmazonS3ConfigurationDelete.errors;
        case DESTINATION_TYPE_HTTP:
        default:
          return this.isInstance
            ? data.instanceExternalAuditEventDestinationDestroy.errors
            : data.externalAuditEventDestinationDestroy.errors;
      }
    },
    async deleteDestination() {
      this.reportDeleting();

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.destinationDestroyMutation,
          variables: {
            id: this.item.id,
            isInstance: this.isInstance,
          },
        });

        const errors = this.destinationErrors(data);

        if (errors.length > 0) {
          this.reportError(new Error(errors[0]));
        } else {
          this.$emit('delete');
        }
      } catch (error) {
        this.reportError(error);
      }
    },
    reportDeleting() {
      this.$emit('deleting');
    },
    reportError(error) {
      this.$emit('error', error);
    },
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API.
    show() {
      this.$refs.modal.show();
    },
  },
  i18n: {
    title: s__('AuditStreams|Are you sure about deleting this destination?'),
    message: s__(
      'AuditStreams|Deleting the streaming destination %{destination} will stop audit events being streamed',
    ),
  },
  buttonProps: {
    primary: {
      text: s__('AuditStreams|Delete destination'),
      attributes: { category: 'primary', variant: 'danger' },
    },
    cancel: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    ref="modal"
    :title="$options.i18n.title"
    modal-id="delete-destination-modal"
    :action-primary="$options.buttonProps.primary"
    :action-cancel="$options.buttonProps.cancel"
    @primary="deleteDestination"
  >
    <gl-sprintf :message="$options.i18n.message">
      <template #destination>
        <strong>{{ destinationTitle }}</strong>
      </template>
    </gl-sprintf>
  </gl-modal>
</template>
