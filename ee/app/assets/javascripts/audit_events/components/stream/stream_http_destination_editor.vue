<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormInputGroup,
  GlInputGroupText,
  GlSprintf,
  GlTableLite,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { isEqual } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { createAlert } from '~/alert';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import externalAuditEventDestinationCreate from '../../graphql/mutations/create_external_destination.mutation.graphql';
import externalAuditEventDestinationUpdate from '../../graphql/mutations/update_external_destination.mutation.graphql';
import deleteExternalDestination from '../../graphql/mutations/delete_external_destination.mutation.graphql';
import externalAuditEventDestinationHeaderCreate from '../../graphql/mutations/create_external_destination_header.mutation.graphql';
import externalAuditEventDestinationHeaderUpdate from '../../graphql/mutations/update_external_destination_header.mutation.graphql';
import externalAuditEventDestinationHeaderDelete from '../../graphql/mutations/delete_external_destination_header.mutation.graphql';
import deleteExternalDestinationFilters from '../../graphql/mutations/delete_external_destination_filters.mutation.graphql';
import addExternalDestinationFilters from '../../graphql/mutations/add_external_destination_filters.mutation.graphql';
import instanceExternalAuditEventDestinationCreate from '../../graphql/mutations/create_instance_external_destination.mutation.graphql';
import instanceExternalAuditEventDestinationUpdate from '../../graphql/mutations/update_instance_external_destination.mutation.graphql';
import deleteInstanceExternalDestination from '../../graphql/mutations/delete_instance_external_destination.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderCreate from '../../graphql/mutations/create_instance_external_destination_header.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderUpdate from '../../graphql/mutations/update_instance_external_destination_header.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderDelete from '../../graphql/mutations/delete_instance_external_destination_header.mutation.graphql';
import deleteInstanceExternalDestinationFilters from '../../graphql/mutations/delete_instance_external_destination_filters.mutation.graphql';
import addInstanceExternalDestinationFilters from '../../graphql/mutations/add_instance_external_destination_filters.mutation.graphql';
import addExternalDestinationNamespaceFilters from '../../graphql/mutations/add_external_destination_namespace_filters.mutation.graphql';
import deleteExternalDestinationNamespaceFilters from '../../graphql/mutations/delete_external_destination_namespace_filters.mutation.graphql';

import {
  ADD_STREAM_EDITOR_I18N,
  AUDIT_STREAMS_NETWORK_ERRORS,
  createBlankHeader,
  DESTINATION_TYPE_HTTP,
} from '../../constants';
import { removeAuditEventsStreamingDestinationFromCache } from '../../graphql/cache_update_consolidated_api';
import {
  addAuditEventsStreamingDestination,
  removeLegacyAuditEventsStreamingDestination,
  addAuditEventStreamingHeader,
  removeAuditEventStreamingHeader,
  updateEventTypeFilters,
  removeEventTypeFilters,
  addNamespaceFilter,
  removeNamespaceFilter,
} from '../../graphql/cache_update';
import { mapAllMutationErrors, mapItemHeadersToFormData } from '../../utils';
import StreamEventTypeFilters from './stream_event_type_filters.vue';
import StreamNamespaceFilters from './stream_namespace_filters.vue';
import StreamDeleteModal from './stream_delete_modal.vue';

const { CREATING_ERROR, UPDATING_ERROR } = AUDIT_STREAMS_NETWORK_ERRORS;

const thClasses = `!gl-p-0 !gl-border-0`;
const tdClasses = `!gl-p-3 !gl-pr-4 !gl-pl-0 !gl-border-0`;
const activeTdClasses = `gl-whitespace-nowrap gl-w-2 ${tdClasses}`;
const actionsTdClasses = `gl-w-2 !gl-py-3 !gl-px-0 !gl-border-0`;

export default {
  name: 'StreamHttpDestinationEditor',
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormInputGroup,
    GlInputGroupText,
    GlSprintf,
    GlTableLite,
    StreamEventTypeFilters,
    StreamNamespaceFilters,
    StreamDeleteModal,
    ClipboardButton,
  },
  directives: {
    GlTooltip,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['groupPath', 'maxHeaders'],
  props: {
    item: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      destinationUrl: '',
      destinationName: '',
      errors: [],
      loading: false,
      headers: [createBlankHeader()],
      filters: [],
      namespaceFilter: { namespace: '', type: 'project' },
    };
  },
  computed: {
    hasNoHeaders() {
      return this.headers.length === 0;
    },
    hasReachedMaxHeaders() {
      return this.headers.length >= this.maxHeaders;
    },
    hasHeaderValidationErrors() {
      return this.headers.some((header) => header.validationErrors.name !== '');
    },
    hasEmptyHeaders() {
      return this.headers.some((header) => !header.name || !header.value);
    },
    isSubmitButtonDisabled() {
      if (
        !this.destinationUrl ||
        !this.destinationName ||
        this.hasHeaderValidationErrors ||
        this.hasEmptyHeaders
      ) {
        return true;
      }

      return this.hasNoChanges;
    },
    hasNoChanges() {
      return (
        !this.headersToAdd.length &&
        !this.headersToUpdate.length &&
        !this.headersToDelete.length &&
        !this.isEventTypeUpdated &&
        !this.isNamespaceUpdated &&
        this.item?.destinationUrl === this.destinationUrl &&
        this.item?.name === this.destinationName
      );
    },
    isEditing() {
      return Boolean(this.item?.destinationUrl || this.item?.config?.url);
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
    isInstance() {
      return this.groupPath === 'instance';
    },
    destinationVariables() {
      return this.isInstance
        ? {
            destinationCreateMutation: instanceExternalAuditEventDestinationCreate,
            destinationUpdateMutation: instanceExternalAuditEventDestinationUpdate,
            destinationDestroyMutation: deleteInstanceExternalDestination,
            headersCreateMutation: externalInstanceAuditEventDestinationHeaderCreate,
            headersUpdateMutation: externalInstanceAuditEventDestinationHeaderUpdate,
            headersDestroyMutation: externalInstanceAuditEventDestinationHeaderDelete,
            headersCreateString: 'auditEventsStreamingInstanceHeadersCreate',
            headersUpdateString: 'auditEventsStreamingInstanceHeadersUpdate',
            headersDestroyString: 'auditEventsStreamingInstanceHeadersDestroy',
            filterAddMutation: addInstanceExternalDestinationFilters,
            filterDestroyMutation: deleteInstanceExternalDestinationFilters,
            namespaceFilterAddMutation: '',
            namespaceFilterDestroyMutation: '',
          }
        : {
            destinationCreateMutation: externalAuditEventDestinationCreate,
            destinationUpdateMutation: externalAuditEventDestinationUpdate,
            destinationDestroyMutation: deleteExternalDestination,
            headersCreateMutation: externalAuditEventDestinationHeaderCreate,
            headersUpdateMutation: externalAuditEventDestinationHeaderUpdate,
            headersDestroyMutation: externalAuditEventDestinationHeaderDelete,
            headersCreateString: 'auditEventsStreamingHeadersCreate',
            headersUpdateString: 'auditEventsStreamingHeadersUpdate',
            headersDestroyString: 'auditEventsStreamingHeadersDestroy',
            filterAddMutation: addExternalDestinationFilters,
            filterDestroyMutation: deleteExternalDestinationFilters,
            namespaceFilterAddMutation: addExternalDestinationNamespaceFilters,
            namespaceFilterDestroyMutation: deleteExternalDestinationNamespaceFilters,
          };
    },
    headersToAdd() {
      return this.headers.filter((header) => header.id === null);
    },
    headersToUpdate() {
      return this.headers.filter((changed) =>
        this.existingHeaders.some(
          (existing) =>
            changed.id === existing.id &&
            (changed.name !== existing.name ||
              changed.value !== existing.value ||
              changed.active !== existing.active),
        ),
      );
    },
    headersToDelete() {
      return this.existingHeaders.filter(
        (existing) => !this.headers.some((changed) => existing.id === changed.id),
      );
    },
    existingHeaders() {
      return mapItemHeadersToFormData(this.item);
    },
    isEventTypeUpdated() {
      return !isEqual(this.item?.eventTypeFilters || [], this.filters);
    },
    isNamespaceUpdated() {
      return !isEqual(
        this.item?.namespaceFilter?.namespace?.fullPath || '',
        this.namespaceFilter?.namespace,
      );
    },
  },
  watch: {
    item() {
      this.headers = mapItemHeadersToFormData(this.item);
    },
  },
  mounted() {
    this.headers = mapItemHeadersToFormData(this.item);
    this.destinationUrl = this.item.destinationUrl || this.item?.config?.url;
    this.destinationName = this.item.name;
    this.filters = this.item.eventTypeFilters || [];
    this.namespaceFilter.namespace =
      this.item?.namespaceFilter?.namespace?.fullPath ||
      this.item?.namespaceFilters?.at(0)?.namespace?.fullPath ||
      '';
    if (
      this.item?.namespaceFilter?.namespace?.id.includes('gid://gitlab/Namespaces::GroupNamespace')
    ) {
      this.namespaceFilter.type = 'group';
    }
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
        ? data.instanceExternalAuditEventDestinationCreate.errors
        : data.externalAuditEventDestinationCreate.errors;
    },
    getDestinationUpdateErrors(data) {
      return this.isInstance
        ? data.instanceExternalAuditEventDestinationUpdate.errors
        : data.externalAuditEventDestinationUpdate.errors;
    },
    getCreateDestination(data) {
      return this.isInstance
        ? data.instanceExternalAuditEventDestinationCreate.instanceExternalAuditEventDestination
        : data.externalAuditEventDestinationCreate.externalAuditEventDestination;
    },
    async addDestinationUrl() {
      const { groupPath: fullPath, isInstance } = this;
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.destinationCreateMutation,
        variables: {
          destinationUrl: this.destinationUrl,
          fullPath: this.groupPath,
          name: this.destinationName,
        },
        update(cache, { data: updateData }) {
          const errors = isInstance
            ? updateData.instanceExternalAuditEventDestinationCreate.errors
            : updateData.externalAuditEventDestinationCreate.errors;
          if (errors.length) {
            return;
          }

          const newDestination = isInstance
            ? updateData.instanceExternalAuditEventDestinationCreate
                .instanceExternalAuditEventDestination
            : updateData.externalAuditEventDestinationCreate.externalAuditEventDestination;

          addAuditEventsStreamingDestination({
            store: cache,
            fullPath,
            newDestination,
          });
        },
      });

      const errors = this.getDestinationCreateErrors(data);
      const externalAuditEventDestination = this.getCreateDestination(data);

      return {
        errors,
        externalAuditEventDestination,
      };
    },
    async updateDestinationUrl(destinationId) {
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.destinationUpdateMutation,
        variables: {
          fullPath: this.groupPath,
          id: destinationId,
          name: this.destinationName,
        },
      });

      const errors = this.getDestinationUpdateErrors(data);
      return { errors };
    },
    async addDestinationHeaders(destinationId, headers) {
      const { groupPath: fullPath, isInstance } = this;
      const mutations = headers.map((header) => {
        return this.$apollo.mutate({
          mutation: this.destinationVariables.headersCreateMutation,
          variables: {
            destinationId,
            key: header.name,
            value: header.value,
            active: header.active,
          },
          update(cache, { data }) {
            const errors = isInstance
              ? data.auditEventsStreamingInstanceHeadersCreate.errors
              : data.auditEventsStreamingHeadersCreate.errors;

            if (errors.length) {
              return;
            }

            const newHeader = isInstance
              ? data.auditEventsStreamingInstanceHeadersCreate.header
              : data.auditEventsStreamingHeadersCreate.header;

            addAuditEventStreamingHeader({
              store: cache,
              fullPath,
              destinationId,
              newHeader,
            });
          },
        });
      });

      return mapAllMutationErrors(mutations, this.destinationVariables.headersCreateString);
    },
    async updateDestinationHeaders(headers) {
      const mutations = headers.map((header) => {
        return this.$apollo.mutate({
          mutation: this.destinationVariables.headersUpdateMutation,
          variables: {
            headerId: header.id,
            key: header.name,
            value: header.value,
            active: header.active,
          },
        });
      });

      return mapAllMutationErrors(mutations, this.destinationVariables.headersUpdateString);
    },
    async deleteDestinationHeaders(headers) {
      const { id: destinationId } = this.item;
      const { groupPath: fullPath, isInstance } = this;
      const mutations = headers.map((header) => {
        return this.$apollo.mutate({
          mutation: this.destinationVariables.headersDestroyMutation,
          variables: {
            headerId: header.id,
          },
          update(cache, { data }) {
            const errors = isInstance
              ? data.auditEventsStreamingInstanceHeadersDestroy.errors
              : data.auditEventsStreamingHeadersDestroy.errors;

            if (errors.length) {
              return;
            }

            removeAuditEventStreamingHeader({
              store: cache,
              fullPath,
              destinationId,
              headerId: header.id,
            });
          },
        });
      });

      return mapAllMutationErrors(mutations, this.destinationVariables.headersDestroyString);
    },
    async deleteCreatedDestination(destinationId) {
      const { groupPath: fullPath, isInstance } = this;
      const removeFn = this.glFeatures.useConsolidatedAuditEventStreamDestApi
        ? removeAuditEventsStreamingDestinationFromCache
        : removeLegacyAuditEventsStreamingDestination;
      return this.$apollo.mutate({
        mutation: this.destinationVariables.destinationDestroyMutation,
        variables: {
          id: destinationId,
        },
        update(cache, { data }) {
          const errors = isInstance
            ? data.instanceExternalAuditEventDestinationDestroy.errors
            : data.externalAuditEventDestinationDestroy.errors;
          if (errors.length) {
            return;
          }

          removeFn({
            store: cache,
            isInstance,
            fullPath,
            destinationId,
          });
        },
      });
    },
    async removeDestinationFilters(destinationId, filters) {
      const { isInstance } = this;
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.filterDestroyMutation,
        variables: {
          destinationId,
          eventTypeFilters: filters,
        },
        update(cache, { data: updateData }) {
          const errors = isInstance
            ? updateData.auditEventsStreamingDestinationInstanceEventsRemove.errors
            : updateData.auditEventsStreamingDestinationEventsRemove.errors;

          if (errors.length) {
            return;
          }

          removeEventTypeFilters({
            store: cache,
            isInstance,
            destinationId,
            filtersToRemove: filters,
          });
        },
      });
      const errorReturned = this.isInstance
        ? data.auditEventsStreamingDestinationInstanceEventsRemove.errors
        : data.auditEventsStreamingDestinationEventsRemove.errors;
      const error = errorReturned || [];

      return error;
    },
    async addDestinationFilters(destinationId, filters) {
      const { isInstance } = this;
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.filterAddMutation,
        variables: {
          destinationId,
          eventTypeFilters: filters,
        },
        update(cache, { data: updateData }) {
          const { errors, eventTypeFilters } = isInstance
            ? updateData.auditEventsStreamingDestinationInstanceEventsAdd
            : updateData.auditEventsStreamingDestinationEventsAdd;

          if (errors.length) {
            return;
          }

          updateEventTypeFilters({
            store: cache,
            isInstance,
            destinationId,
            filters: eventTypeFilters,
          });
        },
      });
      const errorReturned = this.isInstance
        ? data.auditEventsStreamingDestinationInstanceEventsAdd.errors
        : data.auditEventsStreamingDestinationEventsAdd.errors;
      const error = errorReturned || [];

      return error;
    },
    async removeDestinationNamespaceFilters(destinationId, namespaceFilterId) {
      const { groupPath: fullPath } = this;
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.namespaceFilterDestroyMutation,
        variables: {
          namespaceFilterId,
        },
        update(cache, { data: updateData }) {
          const { errors } = updateData.auditEventsStreamingHttpNamespaceFiltersDelete;

          if (errors.length) {
            return;
          }

          removeNamespaceFilter({
            store: cache,
            fullPath,
            destinationId,
          });
        },
      });
      const { errors } = data.auditEventsStreamingHttpNamespaceFiltersDelete;
      const error = errors || [];

      return error;
    },
    async addDestinationNamespaceFilters(destinationId, filter) {
      const { groupPath: fullPath } = this;
      const variables = { destinationId };
      if (filter.type === 'group') {
        variables.groupPath = filter.namespace;
      } else {
        variables.projectPath = filter.namespace;
      }
      const { data } = await this.$apollo.mutate({
        mutation: this.destinationVariables.namespaceFilterAddMutation,
        variables,
        update(cache, { data: updateData }) {
          const { errors, namespaceFilter } =
            updateData.auditEventsStreamingHttpNamespaceFiltersAdd;

          if (errors.length) {
            return;
          }

          addNamespaceFilter({
            store: cache,
            fullPath,
            destinationId,
            filter: namespaceFilter,
          });
        },
      });
      const { errors } = data.auditEventsStreamingHttpNamespaceFiltersAdd;
      const error = errors || [];

      return error;
    },
    async addDestination() {
      let destinationId = null;

      this.errors = [];
      this.loading = true;
      try {
        const errors = [];
        const { errors: destinationErrors = [], externalAuditEventDestination } =
          await this.addDestinationUrl();

        errors.push(...destinationErrors);
        destinationId = externalAuditEventDestination?.id;

        if (!errors.length) {
          errors.push(...(await this.addDestinationHeaders(destinationId, this.headers)));

          if (errors.length > 0) {
            await this.deleteCreatedDestination(destinationId);
          }
        }

        if (this.filters?.length > 0 && destinationId) {
          const addDestinationFiltersErrors = await this.addDestinationFilters(
            destinationId,
            this.filters,
          );
          errors.push(...addDestinationFiltersErrors);
        }

        if (this.namespaceFilter?.namespace) {
          const addDestinationNamespaceFiltersErrors = await this.addDestinationNamespaceFilters(
            destinationId,
            this.namespaceFilter,
          );
          if (addDestinationNamespaceFiltersErrors?.length)
            errors.push(...addDestinationNamespaceFiltersErrors);
        }

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

        if (destinationId) {
          await this.deleteCreatedDestination(destinationId);
        }
      } finally {
        this.loading = false;
      }
    },
    async updateDestination() {
      this.errors = [];
      this.loading = true;

      try {
        const errors = [];
        const { headersToDelete, headersToUpdate, headersToAdd } = this;
        if (this.existingHeaders.length > 0) {
          errors.push(...(await this.deleteDestinationHeaders(headersToDelete)));
          errors.push(...(await this.updateDestinationHeaders(headersToUpdate)));
        }

        errors.push(...(await this.addDestinationHeaders(this.item.id, headersToAdd)));

        const { errors: destinationErrors = [] } = await this.updateDestinationUrl(this.item.id);
        errors.push(...destinationErrors);

        if (this.isEventTypeUpdated) {
          const removeFilters = this.item.eventTypeFilters.filter((f) => !this.filters.includes(f));
          const addFilters = this.filters.filter((f) => !this.item.eventTypeFilters.includes(f));
          if (removeFilters?.length) {
            const removeDestinationFiltersErrors = await this.removeDestinationFilters(
              this.item.id,
              removeFilters,
            );
            errors.push(...removeDestinationFiltersErrors);
          }
          if (addFilters?.length) {
            const addDestinationFiltersErrors = await this.addDestinationFilters(
              this.item.id,
              addFilters,
            );
            if (addDestinationFiltersErrors?.length) errors.push(...addDestinationFiltersErrors);
          }
        }

        if (this.isNamespaceUpdated) {
          if (this.item?.namespaceFilter?.id) {
            const removeDestinationNamespaceFiltersErrors =
              await this.removeDestinationNamespaceFilters(
                this.item?.id,
                this.item?.namespaceFilter?.id,
              );
            if (removeDestinationNamespaceFiltersErrors?.length)
              errors.push(...removeDestinationNamespaceFiltersErrors);
          }

          if (this.namespaceFilter?.namespace) {
            const addDestinationNamespaceFiltersErrors = await this.addDestinationNamespaceFilters(
              this.item?.id,
              this.namespaceFilter,
            );
            if (addDestinationNamespaceFiltersErrors?.length)
              errors.push(...addDestinationNamespaceFiltersErrors);
          }
        }

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
        this.loading = false;
      }
    },
    deleteDestination() {
      this.$refs.deleteModal.show();
    },
    headerNameExists(value) {
      return this.headers.some((header) => header.name === value);
    },
    addBlankHeader() {
      this.headers.push(createBlankHeader());
    },
    setHeaders(index, value) {
      const copy = [...this.headers];
      copy[index] = value;
      this.headers = copy;
    },
    handleHeaderNameInput(index, name) {
      const header = this.headers[index];

      const updatedHeader = {
        ...header,
        name,
        validationErrors: {
          ...header.validationErrors,
          name: '',
        },
      };

      if (name !== '' && this.headerNameExists(name)) {
        updatedHeader.validationErrors.name = ADD_STREAM_EDITOR_I18N.HEADER_INPUT_DUPLICATE_ERROR;
      }

      this.setHeaders(index, updatedHeader);
    },
    handleHeaderValueInput(index, value) {
      this.setHeaders(index, { ...this.headers[index], value });
    },
    handleHeaderActiveInput(index, active) {
      this.setHeaders(index, { ...this.headers[index], active });
    },
    removeHeader(index) {
      const [removedHeader] = this.headers.splice(index, 1);
      const firstSameHeader = this.headers.find((h) => h.name === removedHeader.name);
      if (firstSameHeader) {
        firstSameHeader.validationErrors.name = '';
      }
    },
    formSubmission() {
      return this.isEditing ? this.updateDestination() : this.addDestination();
    },
  },
  i18n: { ...ADD_STREAM_EDITOR_I18N, CREATING_ERROR },
  fields: [
    {
      key: 'active',
      label: '',
      thClass: thClasses,
      tdClass: activeTdClasses,
    },
    {
      key: 'name',
      label: '',
      thClass: thClasses,
      tdClass: tdClasses,
    },
    {
      key: 'value',
      label: '',
      thClass: thClasses,
      tdClass: tdClasses,
    },
    {
      key: 'actions',
      label: '',
      thClass: thClasses,
      tdClass: actionsTdClasses,
    },
  ],
  DESTINATION_TYPE_HTTP,
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
        :label="$options.i18n.DESTINATION_NAME_LABEL"
        data-testid="destination-name-form-group"
      >
        <gl-form-input v-model="destinationName" data-testid="destination-name" />
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.DESTINATION_URL_LABEL"
        data-testid="destination-url-form-group"
      >
        <gl-form-input
          v-model="destinationUrl"
          :placeholder="$options.i18n.DESTINATION_URL_PLACEHOLDER"
          :disabled="isEditing"
          data-testid="destination-url"
        />
      </gl-form-group>

      <gl-form-group
        v-if="isEditing"
        :label="$options.i18n.VERIFICATION_TOKEN_LABEL"
        class="gl-max-w-34"
        data-testid="verification-token-form-group"
      >
        <gl-form-input-group
          readonly
          :value="item.verificationToken || item.secretToken"
          data-testid="verification-token"
        >
          <template #append>
            <clipboard-button
              :text="item.verificationToken || item.secretToken"
              :title="__('Copy to clipboard')"
            />
          </template>
        </gl-form-input-group>
      </gl-form-group>

      <div class="gl-mb-5">
        <label class="gl-mb-3 gl-block gl-text-lg">{{ $options.i18n.HEADERS_LABEL }}</label>
        <gl-table-lite :items="headers" :fields="$options.fields">
          <template #cell(active)="{ index, item: { active } }">
            <gl-form-checkbox
              class="gl-mt-3"
              :checked="active"
              data-testid="header-active-input"
              @input="handleHeaderActiveInput(index, $event)"
            >
              {{ $options.i18n.TABLE_COLUMN_ACTIVE_LABEL }}
            </gl-form-checkbox>
          </template>
          <template
            #cell(name)="{
              index,
              item: {
                disabled,
                validationErrors: { name: feedback = '' },
                name,
              },
            }"
          >
            <gl-form-input-group
              class="gl-m-0"
              label-class="!gl-m-0 !gl-p-0"
              :invalid-feedback="feedback"
            >
              <template #prepend>
                <gl-input-group-text>
                  {{ $options.i18n.TABLE_COLUMN_NAME_LABEL }}
                </gl-input-group-text>
              </template>
              <gl-form-input
                :value="name"
                :placeholder="$options.i18n.HEADER_INPUT_PLACEHOLDER"
                :disabled="disabled"
                :state="feedback === ''"
                data-testid="header-name-input"
                @input="handleHeaderNameInput(index, $event)"
              />
            </gl-form-input-group>
          </template>
          <template #cell(value)="{ index, item: { disabled, value } }">
            <gl-form-input-group class="gl-m-0" label-class="!gl-m-0 !gl-p-0">
              <template #prepend>
                <gl-input-group-text>
                  {{ $options.i18n.TABLE_COLUMN_VALUE_LABEL }}
                </gl-input-group-text>
              </template>
              <gl-form-input
                :value="value"
                :placeholder="$options.i18n.VALUE_INPUT_PLACEHOLDER"
                :disabled="disabled"
                data-testid="header-value-input"
                @input="handleHeaderValueInput(index, $event)"
              />
            </gl-form-input-group>
          </template>
          <template #cell(actions)="{ index }">
            <gl-button
              v-gl-tooltip
              :aria-label="$options.i18n.REMOVE_BUTTON_LABEL"
              :title="$options.i18n.REMOVE_BUTTON_TOOLTIP"
              category="tertiary"
              icon="remove"
              @click="removeHeader(index)"
            />
          </template>
        </gl-table-lite>
        <p v-if="hasNoHeaders" class="gl-mb-5 gl-text-subtle" data-testid="no-header-created">
          {{ $options.i18n.NO_HEADER_CREATED_TEXT }}
        </p>
        <p
          v-if="hasReachedMaxHeaders"
          class="gl-mb-0 gl-mt-5 gl-text-subtle"
          data-testid="maximum-headers"
        >
          <gl-sprintf :message="$options.i18n.MAXIMUM_HEADERS_TEXT">
            <template #number>
              {{ maxHeaders }}
            </template>
          </gl-sprintf>
        </p>
        <gl-button
          v-else
          :loading="loading"
          :name="$options.i18n.ADD_HEADER_ROW_BUTTON_NAME"
          variant="confirm"
          category="secondary"
          size="small"
          data-testid="add-header-row-button"
          @click="addBlankHeader"
        >
          {{ $options.i18n.ADD_HEADER_ROW_BUTTON_TEXT }}
        </gl-button>
      </div>

      <div class="gl-mb-5">
        <label class="gl-block gl-text-lg" data-testid="filtering-header">{{
          $options.i18n.HEADER_FILTERING
        }}</label>
        <div class="gl-ml-5">
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-type-filter"
            data-testid="event-type-filtering-header"
            >{{ $options.i18n.FILTER_BY_AUDIT_EVENT_TYPE }}</label
          >
          <stream-event-type-filters v-model="filters" />
        </div>
        <div v-if="!isInstance" class="gl-ml-5">
          <label
            class="gl-mb-3 gl-mt-5 gl-block"
            for="audit-event-namespace-filter"
            data-testid="event-namespace-filtering-header"
            >{{ $options.i18n.FILTER_BY_NAMESPACE }}</label
          >
          <stream-namespace-filters v-model="namespaceFilter" />
        </div>
      </div>

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
      :type="$options.DESTINATION_TYPE_HTTP"
      :item="item"
      @deleting="onDeleting"
      @delete="onDelete"
      @error="onError"
    />
  </div>
</template>
