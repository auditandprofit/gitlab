<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlIntersperse,
  GlModal,
  GlLoadingIcon,
  GlSprintf,
  GlTooltipDirective,
  GlLink,
} from '@gitlab/ui';
import VueDraggable from 'vuedraggable';
import { s__, __, sprintf } from '~/locale';
import { validateHexColor } from '~/lib/utils/color_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import lifecycleUpdateMutation from './lifecycle_update.mutation.graphql';
import StatusForm from './status_form.vue';
import namespaceMetadataQuery from './namespace_metadata.query.graphql';

const STATUS_CATEGORIES = {
  TRIAGE: 'TRIAGE',
  TO_DO: 'TO_DO',
  IN_PROGRESS: 'IN_PROGRESS',
  DONE: 'DONE',
  CANCELED: 'CANCELED',
};

const CATEGORY_MAP = {
  [STATUS_CATEGORIES.TRIAGE]: {
    icon: 'status-neutral',
    color: '#995715',
    label: s__('WorkItem|Triage'),
    defaultState: 'open',
    description: s__(
      'WorkItem|Use for items that are still in a proposal or ideation phase, not yet accepted or planned for work.',
    ),
  },
  [STATUS_CATEGORIES.TO_DO]: {
    icon: 'status-waiting',
    color: '#737278',
    label: s__('WorkItem|To do'),
    defaultState: 'open',
    description: s__('WorkItem|Use for planned work that is not actively being worked on.'),
  },
  [STATUS_CATEGORIES.IN_PROGRESS]: {
    icon: 'status-running',
    color: '#1f75cb',
    label: s__('WorkItem|In progress'),
    defaultState: 'open',
    description: s__('WorkItem|Use for items that are actively being worked on.'),
  },
  [STATUS_CATEGORIES.DONE]: {
    icon: 'status-success',
    color: '#108548',
    label: s__('WorkItem|Done'),
    defaultState: 'closed',
    description: s__(
      'WorkItem|Use for items that have been completed. Applying a done status will close the item.',
    ),
  },
  [STATUS_CATEGORIES.CANCELED]: {
    icon: 'status-cancelled',
    color: '#dd2b0e',
    label: s__('WorkItem|Canceled'),
    defaultState: 'duplicate',
    description: s__(
      'WorkItem|Use for items that are no longer relevant and will not be completed. Applying a canceled status will close the item.',
    ),
  },
};

const CATEGORY_ORDER = Object.keys(CATEGORY_MAP);

const STATUS_MAX_LIMIT = 30;

export default {
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlIntersperse,
    GlModal,
    GlLoadingIcon,
    GlSprintf,
    StatusForm,
    VueDraggable,
    GlLink,
    HelpPageLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    lifecycle: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      errorMessage: '',
      editingStatusId: null,
      addingToCategory: null,
      removingStatusId: null,
      removingStatusName: '',
      showRemoveConfirmation: false,
      formData: {
        name: '',
        color: '',
        description: '',
      },
      formErrors: {
        name: null,
        color: null,
      },
      namespaceMetadata: null,
    };
  },
  apollo: {
    namespaceMetadata: {
      query: namespaceMetadataQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to fetch namespace metadata.');
        this.errorDetail = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    modalTitle() {
      return s__('WorkItem|Edit statuses');
    },
    statusesByCategory() {
      const grouped = {};
      CATEGORY_ORDER.forEach((category) => {
        grouped[category] = [];
      });

      this.lifecycle.statuses?.forEach((status) => {
        const category = this.getCategoryFromIconName(status.iconName);
        if (grouped[category]) {
          grouped[category].push(status);
        }
      });

      return grouped;
    },
    isEditing() {
      return Boolean(this.editingStatusId);
    },
    removingStatus() {
      return this.lifecycle.statuses?.find((status) => status.id === this.removingStatusId);
    },
    groupWorkItemsPath() {
      return this.namespaceMetadata?.linkPaths?.groupIssues;
    },
    groupWorkItemsPathWithStatusFilter() {
      return `${this.groupWorkItemsPath}?status=${this.removingStatusName}`;
    },
  },
  methods: {
    canReorderStatuses(category) {
      return this.statusesByCategory[category].length >= 2;
    },
    getCategoryFromIconName(iconName) {
      return (
        Object.keys(CATEGORY_MAP).find((category) => CATEGORY_MAP[category].icon === iconName) ||
        STATUS_CATEGORIES.TO_DO
      );
    },
    getCategoryLabel(category) {
      return CATEGORY_MAP[category].label || category;
    },
    getCategoryDescription(category) {
      return CATEGORY_MAP[category].description || '';
    },
    getCategoryDefaultState(category) {
      return CATEGORY_MAP[category].defaultState || '';
    },
    startAddingStatus(category) {
      this.cancelForm();
      this.addingToCategory = category;
      this.resetForm();
    },
    startEditingStatus(status) {
      this.cancelForm();
      this.editingStatusId = status.id;
      this.formData.name = status.name;
      this.formData.color = status.color;
      this.formData.description = status.description || '';
      this.formErrors = {
        name: null,
        color: null,
      };
    },
    startRemovingStatus(status) {
      this.removingStatusId = status.id;
      this.removingStatusName = status.name;
      this.showRemoveConfirmation = true;
    },
    async startDefaultingStatus(status, defaultState) {
      if (!status?.id || !defaultState) {
        return;
      }

      try {
        const defaultStatus = {};

        defaultStatus[defaultState] = {
          id: status.id,
          name: status.name,
          __typename: 'WorkItemStatus',
        };
        const allStatuses = [];

        this.$options.CATEGORY_ORDER.forEach((cat) => {
          const categoryStatuses = this.statusesByCategory[cat];
          allStatuses.push(...categoryStatuses);
        });

        const statusesForUpdate = allStatuses.map((statusValue) => ({
          id: statusValue.id,
          name: statusValue.name,
          color: statusValue.color,
          category: this.getCategoryFromStatus(statusValue.id),
          description: statusValue.description,
        }));

        this.$refs[status.name][0]?.close();

        await this.updateLifecycle(
          statusesForUpdate,
          s__('WorkItem|An error occurred while making status default.'),
          defaultStatus,
        );
      } catch (error) {
        this.errorMessage = s__('WorkItem|An error occurred while making status default.');
      }
    },
    confirmRemoveStatus() {
      if (this.removingStatusId) {
        this.removeStatus(this.removingStatusId);
      }
      this.cancelRemoveStatus();
    },
    cancelRemoveStatus() {
      this.removingStatusId = null;
      this.showRemoveConfirmation = false;
    },
    cancelForm() {
      this.resetForm();
      this.editingStatusId = null;
      this.addingToCategory = null;
    },
    resetForm() {
      const color = this.addingToCategory
        ? this.$options.CATEGORY_MAP[this.addingToCategory].color
        : '';

      this.formData = {
        name: '',
        color,
        description: '',
      };
      this.formErrors = {
        name: null,
        color: null,
      };
      this.errorMessage = '';
    },
    validateForm() {
      if (this.formData.name?.trim() === '') {
        this.formErrors.name = s__('WorkItem|Name is required.');
      } else if (
        this.lifecycle.statuses.find(
          (status) =>
            status.name === this.formData.name?.trim() && status.id !== this.editingStatusId,
        )
      ) {
        this.formErrors.name = s__('WorkItem|Name is already taken.');
      } else {
        this.formErrors.name = null;
      }

      if (!validateHexColor(this.formData.color)) {
        this.formErrors.color = s__('WorkItem|Must be a valid hex color.');
      } else {
        this.formErrors.color = null;
      }

      return Object.values(this.formErrors).every((error) => error === null);
    },
    async updateLifecycle(
      statuses,
      errorMessage = s__('WorkItem|An error occurred while updating the status.'),
      defaultStatus = {},
    ) {
      this.errorMessage = '';
      const { open, closed, duplicate } = defaultStatus;

      const defaultOpenStatusId = open ? open.id : this.lifecycle.defaultOpenStatus?.id;
      const defaultClosedStatusId = closed ? closed.id : this.lifecycle.defaultClosedStatus?.id;
      const defaultDuplicateStatusId = duplicate
        ? duplicate.id
        : this.lifecycle.defaultDuplicateStatus?.id;

      try {
        const defaultOpenStatusIndex = statuses.findIndex((s) => s.id === defaultOpenStatusId);
        const defaultClosedStatusIndex = statuses.findIndex((s) => s.id === defaultClosedStatusId);
        const defaultDuplicateStatusIndex = statuses.findIndex(
          (s) => s.id === defaultDuplicateStatusId,
        );

        const defaultOpenStatus = open || this.lifecycle.defaultOpenStatus;
        const defaultClosedStatus = closed || this.lifecycle.defaultClosedStatus;
        const defaultDuplicateStatus = duplicate || this.lifecycle.defaultDuplicateStatus;

        const { data } = await this.$apollo.mutate({
          mutation: lifecycleUpdateMutation,
          variables: {
            input: {
              namespacePath: this.fullPath,
              id: this.lifecycle.id,
              statuses,
              defaultOpenStatusIndex: Math.max(0, defaultOpenStatusIndex),
              defaultClosedStatusIndex: Math.max(0, defaultClosedStatusIndex),
              defaultDuplicateStatusIndex: Math.max(0, defaultDuplicateStatusIndex),
            },
          },
          optimisticResponse: {
            lifecycleUpdate: {
              lifecycle: {
                id: this.lifecycle.id,
                name: this.lifecycle.name,
                statuses: statuses.map((status) => ({
                  __typename: 'WorkItemStatus',
                  id: status.id || null,
                  name: status.name,
                  iconName: status.category ? CATEGORY_MAP[status.category].icon : 'status-waiting',
                  color: status.color,
                  description: status.description,
                })),
                defaultOpenStatus,
                defaultClosedStatus,
                defaultDuplicateStatus,
                workItemTypes: this.lifecycle.workItemTypes,
                __typename: 'WorkItemLifecycle',
              },
              errors: [],
              __typename: 'LifecycleUpdatePayload',
            },
          },
        });

        if (data?.lifecycleUpdate?.errors?.length) {
          throw new Error(data.lifecycleUpdate.errors.join(', '));
        }

        this.$emit('lifecycle-updated');
      } catch (error) {
        Sentry.captureException(error);
        this.errorMessage = error.message || errorMessage;
        if (error.message.indexOf('because it is in use') !== -1 && this.groupWorkItemsPath) {
          this.errorMessage += '. %{linkStart}View items using status.%{linkEnd}';
        }
      }
    },
    async onStatusReorder({ oldIndex, newIndex }) {
      if (oldIndex === newIndex) {
        return;
      }

      const allStatuses = [];

      this.$options.CATEGORY_ORDER.forEach((cat) => {
        const categoryStatuses = this.statusesByCategory[cat];
        allStatuses.push(...categoryStatuses);
      });

      const statusesForUpdate = allStatuses.map((status) => ({
        id: status.id,
        name: status.name,
        color: status.color,
        category: this.getCategoryFromStatus(status.id),
        description: status.description,
      }));

      await this.updateLifecycle(
        statusesForUpdate,
        s__('WorkItem|An error occurred while reordering statuses.'),
      );
    },
    async saveStatus() {
      if (!this.validateForm()) {
        return;
      }

      const currentStatuses = this.lifecycle.statuses.map((status) => ({
        id: status.id,
        name: status.name,
        color: status.color,
        category: this.getCategoryFromStatus(status.id),
        description: status.description,
      }));

      if (currentStatuses.length >= STATUS_MAX_LIMIT) {
        this.errorMessage = sprintf(
          s__('WorkItem|Maximum %{maxLimit} statuses reached. Remove a status to add more.'),
          {
            maxLimit: STATUS_MAX_LIMIT,
          },
        );
        return;
      }

      if (this.isEditing) {
        const statusIndex = currentStatuses.findIndex((s) => s.id === this.editingStatusId);
        if (statusIndex !== -1) {
          currentStatuses[statusIndex] = {
            ...currentStatuses[statusIndex],
            name: this.formData.name.trim(),
            color: this.formData.color,
            description: this.formData.description.trim(),
          };
        }
      } else {
        currentStatuses.push({
          name: this.formData.name.trim(),
          color: this.formData.color,
          description: this.formData.description.trim(),
          category: this.addingToCategory,
        });
      }

      await this.updateLifecycle(
        currentStatuses,
        s__('WorkItem|An error occurred while saving the status.'),
      );
      this.cancelForm();
    },
    async removeStatus(statusId) {
      const currentStatuses = this.lifecycle.statuses
        .filter((s) => s.id !== statusId)
        .map((status) => ({
          id: status.id,
          name: status.name,
          color: status.color,
        }));

      await this.updateLifecycle(
        currentStatuses,
        s__('WorkItem|An error occurred while removing the status.'),
      );
    },
    getCategoryFromStatus(statusId) {
      for (const [category, statuses] of Object.entries(this.statusesByCategory)) {
        if (statuses.find((status) => status.id === statusId)) {
          return category;
        }
      }
      return STATUS_CATEGORIES.TO_DO;
    },
    isDefaultStatus(status) {
      return (
        status.id === this.lifecycle.defaultOpenStatus?.id ||
        status.id === this.lifecycle.defaultClosedStatus?.id ||
        status.id === this.lifecycle.defaultDuplicateStatus?.id
      );
    },
    getDefaultStatusType(status) {
      if (status.id === this.lifecycle.defaultOpenStatus?.id) {
        return s__('WorkItem|Open default');
      }
      if (status.id === this.lifecycle.defaultClosedStatus?.id) {
        return s__('WorkItem|Closed default');
      }
      if (status.id === this.lifecycle.defaultDuplicateStatus?.id) {
        return s__('WorkItem|Duplicate default');
      }
      return null;
    },
    getDefaultDropdownTextForStatus(defaultState) {
      return sprintf(s__('WorkItem|Make default for %{defaultState} issues'), {
        defaultState,
      });
    },
    closeModal() {
      this.cancelForm();
      this.$emit('close');
    },
    dismissError() {
      this.errorMessage = '';
      this.removingStatusName = '';
    },
  },
  CATEGORY_ORDER,
  CATEGORY_MAP,
  sprintf,
  confirmRemoveStatus: {
    text: s__('WorkItem|Remove'),
    attributes: {
      variant: 'danger',
      'data-testid': 'confirm-remove-status',
    },
  },
  cancelRemoveStatus: {
    text: __('Cancel'),
    attributes: {
      'data-testid': 'cancel-remove-status',
    },
  },
};
</script>

<template>
  <div>
    <gl-modal
      :visible="visible"
      :title="modalTitle"
      scrollable
      modal-id="status-modal"
      @hide="closeModal"
    >
      <gl-loading-icon v-if="loading" size="lg" class="gl-my-7" />

      <template v-else>
        <div class="gl-mb-5 gl-rounded-base gl-bg-strong gl-p-3" data-testid="status-info-alert">
          <gl-sprintf
            class="gl-flex gl-items-center gl-gap-2"
            :message="
              s__(
                'WorkItem|Used on types: %{workItemTypes}. Changes affect all items in all subgroups and projects.',
              )
            "
          >
            <template #workItemTypes>
              <gl-intersperse
                ><span v-for="workItemType in lifecycle.workItemTypes" :key="workItemType.id">{{
                  workItemType.name
                }}</span></gl-intersperse
              >
            </template>
          </gl-sprintf>
          <help-page-link
            data-testid="help-page-link"
            href="user/work_items/status"
            target="_blank"
          >
            {{ s__('WorkItems|How do I use statuses?') }}
          </help-page-link>
        </div>

        <gl-alert
          v-if="errorMessage"
          variant="danger"
          class="gl-sticky gl-top-0 gl-my-5"
          data-testid="error-alert"
          @dismiss="dismissError"
        >
          <gl-sprintf :message="errorMessage">
            <template #link="{ content }">
              <gl-link :href="groupWorkItemsPathWithStatusFilter">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </gl-alert>

        <div
          v-for="category in $options.CATEGORY_ORDER"
          :key="category"
          class="gl-mb-6"
          :data-testid="`category-${category.toLowerCase()}`"
        >
          <div class="gl-mb-2 gl-flex gl-flex-col gl-gap-1">
            <h3 class="gl-m-0 gl-text-size-reset gl-font-bold">
              {{ getCategoryLabel(category) }}
            </h3>
            <p data-testid="category-description" class="!gl-mb-0 gl-text-sm gl-text-subtle">
              {{ getCategoryDescription(category) }}
            </p>
          </div>

          <div>
            <vue-draggable
              :list="statusesByCategory[category]"
              :disabled="!canReorderStatuses(category)"
              :animation="0"
              handle=".js-drag-handle"
              ghost-class="gl-opacity-5"
              @end="onStatusReorder($event)"
            >
              <div
                v-for="status in statusesByCategory[category]"
                :key="status.id"
                class="gl-border-b"
                data-testid="status-badge"
              >
                <div
                  v-if="editingStatusId !== status.id"
                  class="gl-items-flex-start gl-flex gl-gap-2 gl-px-3 gl-py-4"
                >
                  <gl-icon
                    name="grip"
                    :size="12"
                    class="js-drag-handle gl-mt-2 gl-flex-none"
                    :class="{
                      'gl-cursor-grabbing': false,
                      'gl-cursor-grab': canReorderStatuses(category),
                    }"
                    data-testid="drag-handle"
                  />
                  <gl-icon
                    :size="12"
                    :name="status.iconName"
                    :style="{ color: status.color }"
                    class="gl-mr-1 gl-mt-2 gl-flex-none"
                  />
                  <div>
                    <span>{{ status.name }}</span>
                    <gl-badge
                      v-if="isDefaultStatus(status)"
                      size="sm"
                      class="gl-ml-2"
                      data-testid="default-status-badge"
                    >
                      {{ getDefaultStatusType(status) }}
                    </gl-badge>
                    <div v-if="status.description" class="gl-mt-2 gl-text-subtle">
                      {{ status.description }}
                    </div>
                  </div>
                  <gl-disclosure-dropdown
                    :ref="status.name"
                    class="gl-ml-auto gl-items-start"
                    text-sr-only
                    :toggle-text="__('More actions')"
                    no-caret
                    category="tertiary"
                    icon="ellipsis_v"
                    placement="bottom-end"
                    size="small"
                  >
                    <gl-disclosure-dropdown-item
                      :data-testid="`edit-status-${status.id}`"
                      @action="startEditingStatus(status)"
                    >
                      <template #list-item>
                        {{ s__('WorkItem|Edit status') }}
                      </template>
                    </gl-disclosure-dropdown-item>

                    <gl-disclosure-dropdown-item
                      v-if="!isDefaultStatus(status) && getCategoryDefaultState(category)"
                      :data-testid="`make-default-${status.id}`"
                      @action="startDefaultingStatus(status, getCategoryDefaultState(category))"
                    >
                      <template #list-item>
                        {{ getDefaultDropdownTextForStatus(getCategoryDefaultState(category)) }}
                      </template>
                    </gl-disclosure-dropdown-item>

                    <gl-disclosure-dropdown-item
                      :data-testid="`remove-status-${status.id}`"
                      @action="startRemovingStatus(status)"
                    >
                      <template #list-item>
                        {{ s__('WorkItem|Remove status') }}
                      </template>
                    </gl-disclosure-dropdown-item>
                  </gl-disclosure-dropdown>
                </div>

                <status-form
                  v-else
                  :category-icon="$options.CATEGORY_MAP[category].icon"
                  :form-data="formData"
                  :form-errors="formErrors"
                  is-editing
                  @update="formData = $event"
                  @validate="validateForm"
                  @save="saveStatus"
                  @cancel="cancelForm"
                />
              </div>
            </vue-draggable>
          </div>
          <gl-button
            v-if="addingToCategory !== category"
            category="tertiary"
            class="gl-mt-3"
            icon="plus"
            data-testid="add-status-button"
            @click="startAddingStatus(category)"
          >
            {{ s__('WorkItem|Add status') }}
          </gl-button>

          <status-form
            v-if="addingToCategory === category"
            :category-icon="$options.CATEGORY_MAP[category].icon"
            :form-data="formData"
            :form-errors="formErrors"
            @update="formData = $event"
            @save="saveStatus"
            @cancel="cancelForm"
          />
        </div>
      </template>

      <template #modal-footer>
        <gl-button @click="closeModal">{{ __('Close') }}</gl-button>
      </template>
    </gl-modal>
    <gl-modal
      v-if="removingStatus"
      :visible="showRemoveConfirmation"
      :title="s__('WorkItem|Remove status')"
      size="sm"
      modal-id="remove-status-confirmation-modal"
      :action-primary="$options.confirmRemoveStatus"
      :action-cancel="$options.cancelRemoveStatus"
      data-testid="remove-status-confirmation-modal"
      @primary="confirmRemoveStatus"
      @hide="cancelRemoveStatus"
    >
      <p class="gl-mb-0">
        {{
          sprintf(
            s__('WorkItem|Are you sure you want to remove the %{statusName} status?'),
            {
              statusName: removingStatus.name,
            },
            false,
          )
        }}
      </p>
      <p class="gl-mb-0 gl-text-subtle">
        {{ s__('WorkItem|This action cannot be undone.') }}
      </p>
    </gl-modal>
  </div>
</template>
