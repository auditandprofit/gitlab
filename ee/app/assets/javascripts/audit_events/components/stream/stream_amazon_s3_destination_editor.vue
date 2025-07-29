<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { isEmpty } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import amazonS3ConfigurationCreate from '../../graphql/mutations/create_amazon_s3_destination.mutation.graphql';
import amazonS3ConfigurationUpdate from '../../graphql/mutations/update_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationCreate from '../../graphql/mutations/create_instance_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationUpdate from '../../graphql/mutations/update_instance_amazon_s3_destination.mutation.graphql';
import {
  ADD_STREAM_EDITOR_I18N,
  AUDIT_STREAMS_NETWORK_ERRORS,
  DESTINATION_TYPE_AMAZON_S3,
} from '../../constants';
import { addAmazonS3AuditEventsStreamingDestination } from '../../graphql/cache_update';
import StreamDeleteModal from './stream_delete_modal.vue';

const { CREATING_ERROR, UPDATING_ERROR } = AUDIT_STREAMS_NETWORK_ERRORS;

export default {
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    StreamDeleteModal,
  },
  directives: {
    GlTooltip,
  },
  inject: ['groupPath'],
  props: {
    item: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      name: this.item.name,
      accessKeyXid: this.item.accessKeyXid || this.item?.config?.accessKeyXid,
      secretAccessKey: null,
      awsRegion: this.item.awsRegion || this.item?.config?.awsRegion,
      bucketName: this.item.bucketName || this.item?.config?.bucketName,
      errors: [],
      loading: false,
      addingSecretAccessKey: false,
    };
  },
  computed: {
    isSubmitButtonDisabled() {
      const { accessKeyXid, awsRegion, bucketName, name } = this.item;

      if (!this.accessKeyXid || !this.awsRegion || !this.bucketName || !this.name) {
        return true;
      }

      if (
        this.isEditing &&
        (accessKeyXid !== this.accessKeyXid ||
          awsRegion !== this.awsRegion ||
          bucketName !== this.bucketName ||
          name !== this.name ||
          this.secretAccessKey)
      ) {
        return false;
      }

      if (
        !this.isEditing &&
        this.accessKeyXid &&
        this.secretAccessKey &&
        this.awsRegion &&
        this.bucketName &&
        this.name
      ) {
        return false;
      }

      return true;
    },
    isEditing() {
      return !isEmpty(this.item);
    },
    addButtonName() {
      return this.isEditing
        ? ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME
        : ADD_STREAM_EDITOR_I18N.ADD_BUTTON_NAME;
    },
    addButtonText() {
      return this.isEditing
        ? ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT
        : ADD_STREAM_EDITOR_I18N.ADD_BUTTON_TEXT;
    },
    showSecretAccessKey() {
      return !this.isEditing || (this.isEditing && this.addingSecretAccessKey);
    },
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationCreateMutation() {
      return this.isInstance ? instanceAmazonS3ConfigurationCreate : amazonS3ConfigurationCreate;
    },
    destinationUpdateMutation() {
      return this.isInstance ? instanceAmazonS3ConfigurationUpdate : amazonS3ConfigurationUpdate;
    },
  },
  methods: {
    onDeleting() {
      this.loading = true;
    },
    onDelete() {
      this.$emit('deleted', this.item.id);
      this.loading = false;
    },
    onError(error) {
      this.loading = false;
      createAlert({
        message: AUDIT_STREAMS_NETWORK_ERRORS.DELETING_ERROR,
        captureError: true,
        error,
      });
      this.$emit('error');
    },
    clearError(index) {
      this.errors.splice(index, 1);
    },
    getDestinationCreateErrors(data) {
      return this.isInstance
        ? data.auditEventsInstanceAmazonS3ConfigurationCreate.errors
        : data.auditEventsAmazonS3ConfigurationCreate.errors;
    },
    getDestinationUpdateErrors(data) {
      return this.isInstance
        ? data.auditEventsInstanceAmazonS3ConfigurationUpdate.errors
        : data.auditEventsAmazonS3ConfigurationUpdate.errors;
    },
    async addDestination() {
      this.errors = [];
      this.loading = true;

      try {
        const { isInstance } = this;
        const { data } = await this.$apollo.mutate({
          mutation: this.destinationCreateMutation,
          variables: {
            id: this.item.id,
            fullPath: this.groupPath,
            name: this.name,
            accessKeyXid: this.accessKeyXid,
            secretAccessKey: this.secretAccessKey,
            awsRegion: this.awsRegion,
            bucketName: this.bucketName,
          },
          update(cache, { data: updateData }, args) {
            const errors = isInstance
              ? updateData.auditEventsInstanceAmazonS3ConfigurationCreate.errors
              : updateData.auditEventsAmazonS3ConfigurationCreate.errors;

            if (errors.length) {
              return;
            }

            const newAmazonS3Destination = isInstance
              ? updateData.auditEventsInstanceAmazonS3ConfigurationCreate
                  .instanceAmazonS3Configuration
              : updateData.auditEventsAmazonS3ConfigurationCreate.amazonS3Configuration;

            addAmazonS3AuditEventsStreamingDestination({
              store: cache,
              fullPath: args.variables.fullPath,
              newDestination: newAmazonS3Destination,
            });
          },
        });

        const errors = this.getDestinationCreateErrors(data);

        if (errors.length > 0) {
          this.errors.push(...errors);
          this.$emit('error');
        } else {
          this.$emit('added');
        }
      } catch (e) {
        Sentry.captureException(e);
        this.errors.push(CREATING_ERROR);
        this.$emit('error');
      } finally {
        this.loading = false;
      }
    },
    async updateDestination() {
      this.errors = [];
      this.loading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.destinationUpdateMutation,
          variables: {
            id: this.item.id,
            fullPath: this.groupPath,
            name: this.name,
            accessKeyXid: this.accessKeyXid,
            secretAccessKey: this.secretAccessKey,
            awsRegion: this.awsRegion,
            bucketName: this.bucketName,
          },
        });

        const errors = this.getDestinationUpdateErrors(data);

        if (errors.length > 0) {
          this.errors.push(...errors);
          this.$emit('error');
        } else {
          this.$emit('updated');
        }
      } catch (e) {
        Sentry.captureException(e);
        this.errors.push(UPDATING_ERROR);
        this.$emit('error');
      } finally {
        this.addingSecretAccessKey = false;
        this.loading = false;
      }
    },
    deleteDestination() {
      this.$refs.deleteModal.show();
    },
    formSubmission() {
      return this.isEditing ? this.updateDestination() : this.addDestination();
    },
    secretAccessKeyFormatter(value) {
      return value.replaceAll('\\n', '\n');
    },
  },
  i18n: ADD_STREAM_EDITOR_I18N,
  DESTINATION_TYPE_AMAZON_S3,
};
</script>

<template>
  <div>
    <gl-alert
      v-if="!isEditing"
      :title="$options.i18n.WARNING_TITLE"
      :dismissible="false"
      class="gl-mb-5"
      data-testid="data-warning"
      variant="warning"
    >
      {{ $options.i18n.WARNING_CONTENT }}
    </gl-alert>

    <gl-alert
      v-for="(error, index) in errors"
      :key="index"
      :dismissible="true"
      class="gl-mb-5"
      data-testid="alert-errors"
      variant="danger"
      @dismiss="clearError(index)"
    >
      {{ error }}
    </gl-alert>

    <gl-form @submit.prevent="formSubmission">
      <gl-form-group
        :label="$options.i18n.AMAZON_S3_DESTINATION_NAME_LABEL"
        data-testid="name-form-group"
      >
        <gl-form-input
          v-model="name"
          data-testid="name"
          :placeholder="$options.i18n.AMAZON_S3_DESTINATION_NAME_PLACEHOLDER"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.AMAZON_S3_DESTINATION_ACCESS_KEY_XID_LABEL"
        data-testid="access-key-xid-form-group"
      >
        <gl-form-input
          v-model="accessKeyXid"
          :placeholder="$options.i18n.AMAZON_S3_DESTINATION_ACCESS_KEY_XID_PLACEHOLDER"
          data-testid="access-key-xid"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.AMAZON_S3_DESTINATION_AWS_REGION_LABEL"
        data-testid="aws-region-form-group"
      >
        <gl-form-input
          v-model="awsRegion"
          :placeholder="$options.i18n.AMAZON_S3_DESTINATION_AWS_REGION_PLACEHOLDER"
          data-testid="aws-region"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.AMAZON_S3_DESTINATION_BUCKET_NAME_LABEL"
        data-testid="bucket-name-form-group"
      >
        <gl-form-input
          v-model="bucketName"
          :placeholder="$options.i18n.AMAZON_S3_DESTINATION_BUCKET_NAME_PLACEHOLDER"
          data-testid="bucket-name"
        />
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.AMAZON_S3_DESTINATION_SECRET_ACCESS_KEY_LABEL"
        data-testid="secret-access-key-form-group"
      >
        <div v-if="isEditing" class="gl-pb-3">
          {{ $options.i18n.AMAZON_S3_DESTINATION_SECRET_ACCESS_KEY_SUBTEXT }}
          <gl-button
            size="small"
            category="secondary"
            variant="confirm"
            data-testid="secret-access-key-add-button"
            :disabled="showSecretAccessKey"
            @click="addingSecretAccessKey = !addingSecretAccessKey"
            >{{
              $options.i18n.AMAZON_S3_DESTINATION_SECRET_ACCESS_KEY_SUBTEXT_ADD_BUTTON
            }}</gl-button
          >
          <gl-button
            v-if="showSecretAccessKey"
            size="small"
            data-testid="secret-access-key-cancel-button"
            @click="addingSecretAccessKey = !addingSecretAccessKey"
            >{{ $options.i18n.CANCEL_BUTTON_TEXT }}</gl-button
          >
        </div>
        <gl-form-textarea
          v-if="showSecretAccessKey"
          v-model="secretAccessKey"
          rows="16"
          no-resize
          :formatter="secretAccessKeyFormatter"
          class="!gl-h-auto"
          data-testid="secret-access-key"
        />
      </gl-form-group>

      <div class="gl-flex">
        <gl-button
          :disabled="isSubmitButtonDisabled"
          :loading="loading"
          :name="addButtonName"
          class="gl-mr-3"
          variant="confirm"
          type="submit"
          data-testid="stream-destination-submit-button"
          >{{ addButtonText }}</gl-button
        >
        <gl-button
          :name="$options.i18n.CANCEL_BUTTON_NAME"
          data-testid="stream-destination-cancel-button"
          @click="$emit('cancel')"
          >{{ $options.i18n.CANCEL_BUTTON_TEXT }}</gl-button
        >
        <gl-button
          v-if="isEditing"
          :name="$options.i18n.DELETE_BUTTON_TEXT"
          :loading="loading"
          variant="danger"
          class="gl-ml-auto"
          data-testid="stream-destination-delete-button"
          @click="deleteDestination"
          >{{ $options.i18n.DELETE_BUTTON_TEXT }}</gl-button
        >
      </div>
    </gl-form>
    <stream-delete-modal
      v-if="isEditing"
      ref="deleteModal"
      :type="$options.DESTINATION_TYPE_AMAZON_S3"
      :item="item"
      @deleting="onDeleting"
      @delete="onDelete"
      @error="onError"
    />
  </div>
</template>
