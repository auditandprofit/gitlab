<script>
import {
  GlLoadingIcon,
  GlTable,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlBadge,
  GlTooltip,
  GlPagination,
} from '@gitlab/ui';

import { s__, __, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { emptyRequirement, requirementEvents, maxRequirementsNumber } from '../constants';
import { EXTERNAL_CONTROL_LABEL } from '../../../../constants';
import { getControls } from '../../../../utils';

import complianceRequirementControlsQuery from '../../../../graphql/compliance_requirement_controls.query.graphql';
import EditSection from './edit_section.vue';
import RequirementModal from './requirement_modal.vue';

export default {
  name: 'FrameworkRequirements',
  components: {
    EditSection,
    RequirementModal,
    GlLoadingIcon,
    GlTable,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlBadge,
    GlTooltip,
    GlPagination,
  },
  props: {
    requirements: {
      type: Array,
      required: true,
    },
    isNewFramework: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    complianceRequirementControls: {
      query: complianceRequirementControlsQuery,
      update: (data) => {
        return data.complianceRequirementControls.controlExpressions || [];
      },
      error(e) {
        createAlert({
          message: s__(
            'ComplianceFrameworks|Error fetching compliance requirements controls data. Please refresh the page.',
          ),
          captureException: true,
          error: e,
        });
      },
      skip() {
        return !this.isExpanded;
      },
    },
  },
  data() {
    return {
      isExpanded: false,
      requirementToEdit: {},
      complianceRequirementControls: [],
      currentPage: 1,
      perPage: 10,
    };
  },
  computed: {
    requirementsWithControls() {
      return this.requirements.map((requirement) => {
        const controls = this.getControls(
          requirement.stagedControls || requirement.complianceRequirementsControls?.nodes || [],
        );
        return {
          ...requirement,
          controls,
        };
      });
    },
    addingRequirementsDisabled() {
      return this.requirements.length >= maxRequirementsNumber;
    },
    disabledAddRequirementBtnText() {
      return sprintf(
        s__(
          'ComplianceFrameworks|You can create a maximum of %{maxRequirementsNumber} requirements',
        ),
        { maxRequirementsNumber },
      );
    },
    showPagination() {
      return this.requirements.length > this.perPage;
    },
  },
  methods: {
    showRequirementModal(requirement, index = null) {
      this.requirementToEdit = { ...requirement, index };
      this.$nextTick(() => {
        this.$refs.requirementModal.show();
      });
    },
    handleCreate({ requirement, index }) {
      this.$emit(requirementEvents.create, { requirement, index });
      this.requirementToEdit = null;
    },
    handleUpdate({ requirement, index }) {
      this.$emit(requirementEvents.update, { requirement, index });
      this.requirementToEdit = null;
    },
    getControls(requirementControlNodes) {
      return getControls(requirementControlNodes, this.complianceRequirementControls);
    },
    pageChanged(newPage) {
      this.currentPage = newPage;
    },
  },
  tableFields: [
    {
      key: 'name',
      label: s__('ComplianceFrameworks|Requirement name'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default',
    },
    {
      key: 'description',
      label: s__('ComplianceFrameworks|Description'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default',
    },
    {
      key: 'controls',
      label: s__('ComplianceFrameworks|Controls'),
      thClass: 'gl-w-1 !gl-border-t-0',
      tdClass: '!gl-bg-default',
    },
    {
      key: 'action',
      thAlignRight: true,
      label: s__('ComplianceFrameworks|Action'),
      thClass: 'gl-w-1 !gl-border-t-0 gl-w-1/10',
      tdClass: '!gl-text-right !gl-bg-default',
    },
  ],
  i18n: {
    requirements: s__('ComplianceFrameworks|Requirements'),
    requirementsDescription: s__(
      'ComplianceFrameworks|Configure requirements set forth by laws, regulations, and industry standards.',
    ),
    actionEdit: __('Edit'),
    actionDelete: __('Delete'),
    newRequirement: s__('ComplianceFrameworks|New requirement'),
  },
  emptyRequirement,
  requirementEvents,
  EXTERNAL_CONTROL_LABEL,
};
</script>
<template>
  <edit-section
    :title="$options.i18n.requirements"
    :description="$options.i18n.requirementsDescription"
    :items-count="requirements.length"
    :initially-expanded="isNewFramework"
    @toggle="isExpanded = $event"
  >
    <gl-table
      v-if="requirements.length"
      ref="requirementsTable"
      class="requirements-table gl-mb-6"
      :items="requirementsWithControls"
      :fields="$options.tableFields"
      :per-page="perPage"
      :current-page="currentPage"
      responsive
      stacked="md"
      hover
      select-mode="single"
      selected-variant="primary"
      data-testid="requirements-table"
    >
      <template #cell(name)="{ item }">
        {{ item.name }}
      </template>
      <template #cell(description)="{ item }">
        {{ item.description }}
      </template>
      <template #cell(controls)="{ item }">
        <ul v-if="item.controls.length" class="gl-m-0 gl-pl-4">
          <li v-for="control in item.controls" :key="control.id">
            {{ control.displayValue }}
            <gl-badge v-if="control.controlType === 'external'">
              {{ $options.EXTERNAL_CONTROL_LABEL }}
            </gl-badge>
          </li>
        </ul>
      </template>

      <template #cell(action)="{ item, index }">
        <gl-disclosure-dropdown
          icon="ellipsis_v"
          text-sr-only
          category="tertiary"
          placement="bottom-end"
          boundary="viewport"
          no-caret
        >
          <gl-disclosure-dropdown-item
            data-testid="edit-action"
            @action="showRequirementModal(item, index)"
          >
            <template #list-item>
              {{ $options.i18n.actionEdit }}
            </template>
          </gl-disclosure-dropdown-item>

          <gl-disclosure-dropdown-item
            data-testid="delete-action"
            @action="$emit($options.requirementEvents.delete, index)"
          >
            <template #list-item>
              {{ $options.i18n.actionDelete }}
            </template>
          </gl-disclosure-dropdown-item>
        </gl-disclosure-dropdown>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>

    <gl-pagination
      v-if="showPagination"
      :value="currentPage"
      :per-page="perPage"
      :total-items="requirements.length"
      align="center"
      class="gl-mt-5"
      data-testid="requirements-pagination"
      @input="pageChanged"
    />

    <gl-tooltip
      v-if="addingRequirementsDisabled"
      placement="right"
      :target="() => $refs.addRequirementBtn"
      :title="disabledAddRequirementBtnText"
    />
    <div ref="addRequirementBtn" class="gl-inline-block">
      <gl-button
        variant="confirm"
        category="secondary"
        size="small"
        class="gl-ml-5"
        data-testid="add-requirement-button"
        :disabled="addingRequirementsDisabled"
        @click="showRequirementModal($options.emptyRequirement)"
      >
        {{ $options.i18n.newRequirement }}
      </gl-button>
    </div>
    <requirement-modal
      v-if="requirementToEdit"
      ref="requirementModal"
      :gitlab-standard-controls="complianceRequirementControls"
      :requirement="requirementToEdit"
      :is-new-framework="isNewFramework"
      @[$options.requirementEvents.create]="handleCreate"
      @[$options.requirementEvents.update]="handleUpdate"
    />
  </edit-section>
</template>
