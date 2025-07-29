<script>
import { GlAlert, GlButton, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import StatusModal from './status_modal.vue';
import namespaceStatusesQuery from './namespace_lifecycles.query.graphql';

export default {
  components: { GlAlert, GlButton, GlIcon, StatusModal, WorkItemStatusBadge, HelpPageLink },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      lifecycles: [],
      errorText: '',
      errorDetail: '',
      selectedLifecycleId: null,
    };
  },
  apollo: {
    lifecycles: {
      query: namespaceStatusesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.lifecycles?.nodes || [];
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load statuses.');
        this.errorDetail = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    selectedLifecycle() {
      return this.lifecycles.find((lifecycle) => lifecycle.id === this.selectedLifecycleId);
    },
  },
  methods: {
    dismissAlert() {
      this.errorText = '';
      this.errorDetail = '';
    },
    openStatusModal(lifecycleId) {
      this.selectedLifecycleId = lifecycleId;
    },
    closeModal() {
      this.selectedLifecycleId = null;
    },
    handleLifecycleUpdate() {
      this.$apollo.queries.lifecycles.refetch();
    },
  },
};
</script>

<template>
  <div>
    <h2 class="settings-title gl-heading-3 gl-mb-1 gl-mt-5">{{ s__('WorkItem|Statuses') }}</h2>
    <p class="gl-mb-3 gl-text-subtle">
      {{
        s__(
          'WorkItem|Statuses are used to manage workflow of planning items, helping you and your team understand how far an item has progressed.',
        )
      }}
      <help-page-link
        data-testid="settings-help-page-link"
        href="user/work_items/status"
        target="_blank"
      >
        {{ s__('WorkItems|How do I use statuses?') }}
      </help-page-link>
    </p>

    <gl-alert
      v-if="errorText"
      variant="danger"
      :dismissible="true"
      class="gl-mb-5"
      data-testid="alert"
      @dismiss="dismissAlert"
    >
      {{ errorText }}
      <details>
        {{ errorDetail }}
      </details>
    </gl-alert>

    <div
      v-for="lifecycle in lifecycles"
      :key="lifecycle.id"
      class="gl-border gl-rounded-base gl-px-5 gl-py-4"
      data-testid="lifecycle-container"
    >
      <div class="gl-mb-3 gl-flex gl-gap-3">
        <span
          v-for="workItemType in lifecycle.workItemTypes"
          :key="workItemType.id"
          class="gl-text-subtle"
        >
          <gl-icon :name="workItemType.iconName" />
          <span>{{ workItemType.name }}</span>
        </span>
      </div>

      <div class="gl-mx-auto gl-my-3 gl-flex gl-flex-wrap gl-gap-3">
        <div v-for="status in lifecycle.statuses" :key="status.id" class="gl-max-w-20">
          <work-item-status-badge :key="status.id" :item="status" />
        </div>
      </div>

      <gl-button size="small" @click="openStatusModal(lifecycle.id)">{{
        s__('WorkItem|Edit statuses')
      }}</gl-button>
    </div>

    <status-modal
      v-if="selectedLifecycle"
      :visible="Boolean(selectedLifecycleId)"
      :lifecycle="selectedLifecycle"
      :full-path="fullPath"
      @close="closeModal"
      @lifecycle-updated="handleLifecycleUpdate"
    />
  </div>
</template>
