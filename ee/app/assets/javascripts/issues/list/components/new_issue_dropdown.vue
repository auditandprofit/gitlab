<script>
import {
  GlButtonGroup,
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { sprintfWorkItem, WORK_ITEM_TYPE_NAME_OBJECTIVE } from '~/work_items/constants';

export default {
  WORK_ITEM_TYPE_NAME_OBJECTIVE,
  i18n: {
    newIssueLabel: __('New issue'),
    toggleSrText: __('Issue type'),
    newObjectiveLabel: sprintfWorkItem(s__('WorkItem|New %{workItemType}')),
  },
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlButton,
    GlButtonGroup,
    CreateWorkItemModal: () => import('~/work_items/components/create_work_item_modal.vue'),
  },
  inject: ['newIssuePath'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      newIssueItem: {
        text: this.$options.i18n.newIssueLabel,
        href: this.newIssuePath,
      },
    };
  },
};
</script>

<template>
  <gl-button-group class="gl-w-full">
    <gl-button variant="confirm" :href="newIssuePath">
      {{ $options.i18n.newIssueLabel }}
    </gl-button>
    <gl-disclosure-dropdown
      :toggle-text="$options.i18n.toggleSrText"
      placement="bottom-end"
      text-sr-only
      variant="confirm"
      toggle-class="!gl-h-7"
      class="!gl-m-0 !gl-w-7"
    >
      <gl-disclosure-dropdown-item :item="newIssueItem" />
      <create-work-item-modal
        :full-path="fullPath"
        :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_OBJECTIVE"
        as-dropdown-item
        @workItemCreated="$emit('workItemCreated')"
      />
    </gl-disclosure-dropdown>
  </gl-button-group>
</template>
