<script>
import { GlDisclosureDropdown } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';

import { s__, __ } from '~/locale';

export default {
  components: {
    GlDisclosureDropdown,
  },
  props: {
    allowSubEpics: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['parentItem']),
    canReadRelation() {
      return this.parentItem.userPermissions.canReadRelation;
    },
    epicActionItems() {
      const epicActionItems = [];

      if (this.parentItem.userPermissions.canAdmin) {
        epicActionItems.push({
          text: s__('Epics|Add a new epic'),
          action: () => this.$emit('showCreateEpicForm'),
        });
      }
      epicActionItems.push({
        text: s__('Epics|Add an existing epic'),
        action: () => this.$emit('showAddEpicForm'),
      });

      return {
        name: __('Epic'),
        items: epicActionItems,
      };
    },
    actions() {
      const actions = [
        {
          name: __('Issue'),
          items: [
            {
              text: __('Add a new issue'),
              action: () => this.$emit('showCreateIssueForm'),
            },
            {
              text: __('Add an existing issue'),
              action: () => this.$emit('showAddIssueForm'),
            },
          ],
        },
      ];

      if (this.allowSubEpics && this.canReadRelation) {
        actions.push(this.epicActionItems);
      }

      return actions;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    :toggle-text="__('Add')"
    :items="actions"
    size="small"
    placement="bottom-end"
    data-testid="epic-issue-actions-split-button"
  />
</template>
