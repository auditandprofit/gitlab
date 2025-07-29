<script>
import { GlLoadingIcon, GlToast, GlAlert } from '@gitlab/ui';
import Vue from 'vue';
import { s__, __, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import SystemNote from '~/work_items/components/notes/system_note.vue';
import updateProjectComplianceViolation from '../graphql/mutations/update_project_compliance_violation.mutation.graphql';
import complianceViolationQuery from '../graphql/compliance_violation.query.graphql';
import AuditEvent from './audit_event.vue';
import FixSuggestionSection from './fix_suggestion_section.vue';
import ViolationSection from './violation_section.vue';

Vue.use(GlToast);

export default {
  name: 'ComplianceViolationDetailsApp',
  components: {
    AuditEvent,
    ComplianceViolationStatusDropdown,
    FixSuggestionSection,
    GlAlert,
    GlLoadingIcon,
    ViolationSection,
    SystemNote,
  },
  props: {
    violationId: {
      type: String,
      required: true,
    },
    complianceCenterPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      queryError: false,
      projectComplianceViolation: {},
      isStatusUpdating: false,
    };
  },
  apollo: {
    projectComplianceViolation: {
      query: complianceViolationQuery,
      variables() {
        return {
          id: this.graphqlViolationId,
        };
      },
      update(data) {
        return data?.projectComplianceViolation;
      },
      error(e) {
        Sentry.captureException(e);
        this.queryError = true;
      },
    },
  },
  computed: {
    graphqlViolationId() {
      return `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${this.violationId}`;
    },
    isLoading() {
      return this.$apollo.queries.projectComplianceViolation.loading;
    },
    hasViolationData() {
      return this.projectComplianceViolation && this.projectComplianceViolation.id;
    },
    title() {
      if (!this.hasViolationData) return '';
      return sprintf(__('Details of violation-%{violationId}'), {
        violationId: this.violationId,
      });
    },
    hasNotes() {
      return this.projectComplianceViolation?.notes?.nodes?.length > 0;
    },
    notesNodes() {
      if (!this.hasNotes) return [];
      return this.projectComplianceViolation.notes.nodes;
    },
    systemNotes() {
      return this.notesNodes.filter((note) => note.system);
    },
    hasSystemNotes() {
      return this.systemNotes.length > 0;
    },
  },
  methods: {
    async handleStatusChange(newStatus) {
      this.isStatusUpdating = true;
      try {
        const result = await this.$apollo.mutate({
          mutation: updateProjectComplianceViolation,
          variables: {
            input: {
              id: this.graphqlViolationId,
              status: newStatus.toUpperCase(),
            },
          },
        });

        if (result.data?.updateProjectComplianceViolation?.errors?.length > 0) {
          throw new Error(result.data.updateProjectComplianceViolation.errors.join(', '));
        }

        this.$toast.show(this.$options.i18n.statusUpdateSuccess, {
          variant: 'success',
        });
      } catch (error) {
        this.$toast.show(this.$options.i18n.statusUpdateError, {
          variant: 'danger',
        });
      } finally {
        this.isStatusUpdating = false;
      }
    },
  },
  i18n: {
    status: s__('ComplianceReport|Status'),
    location: s__('ComplianceReport|Location'),
    queryError: s__(
      'ComplianceReport|Failed to load the compliance violation. Refresh the page and try again.',
    ),
    statusUpdateError: s__(
      'ComplianceReport|Failed to update compliance violation status. Please try again later.',
    ),
    statusUpdateSuccess: s__('ComplianceReport|Violation status updated successfully.'),
    activity: s__('ComplianceReport|Activity'),
  },
};
</script>
<template>
  <gl-alert v-if="queryError" variant="danger" class="gl-mt-3" :dismissible="false">
    {{ $options.i18n.queryError }}
  </gl-alert>
  <gl-loading-icon
    v-else-if="isLoading"
    data-testid="compliance-violation-details-loading-status"
    class="gl-mt-5"
  />
  <div v-else-if="hasViolationData" data-testid="compliance-violation-details">
    <h1 class="page-title gl-text-size-h-display" data-testid="compliance-violation-title">
      {{ title }}
    </h1>
    <div class="gl-mt-5" data-testid="compliance-violation-status">
      <span class="gl-font-bold">{{ $options.i18n.status }}:</span>
      <compliance-violation-status-dropdown
        class="gl-ml-3 gl-align-baseline"
        :value="projectComplianceViolation.status.toLowerCase()"
        :loading="isStatusUpdating"
        @change="handleStatusChange"
      />
    </div>
    <div class="gl-mt-4">
      <span class="gl-font-bold">{{ $options.i18n.location }}:</span>
      <a
        :href="projectComplianceViolation.project.webUrl"
        data-testid="compliance-violation-location-link"
      >
        {{ projectComplianceViolation.project.nameWithNamespace }}
      </a>
    </div>
    <audit-event
      v-if="projectComplianceViolation.auditEvent"
      class="gl-mt-5"
      :audit-event="projectComplianceViolation.auditEvent"
    />
    <violation-section
      class="gl-mt-5"
      :control="projectComplianceViolation.complianceControl"
      :compliance-center-path="complianceCenterPath"
    />
    <fix-suggestion-section
      class="gl-mt-5"
      :control-id="projectComplianceViolation.complianceControl.name"
      :project-path="projectComplianceViolation.project.webUrl"
    />
    <section v-if="hasSystemNotes" class="issuable-discussion gl-pt-6">
      <h2 class="gl-mb-4 gl-mt-0 gl-text-size-h1">{{ $options.i18n.activity }}</h2>
      <ul class="timeline main-notes-list notes">
        <system-note v-for="note in systemNotes" :key="note.id" :note="note" />
      </ul>
    </section>
  </div>
</template>
