<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { TYPE_EPIC, TYPE_ISSUE } from '~/issues/constants';
import { ParentType } from '../constants';
import EpicActionsSplitButton from './epic_issue_actions_split_button.vue';

export default {
  components: {
    EpicActionsSplitButton,
  },
  computed: {
    ...mapState(['parentItem', 'allowSubEpics']),
    parentIsEpic() {
      return this.parentItem.type === ParentType.Epic;
    },
  },
  methods: {
    ...mapActions([
      'toggleCreateIssueForm',
      'toggleAddItemForm',
      'toggleCreateEpicForm',
      'setItemInputValue',
    ]),
    showAddIssueForm() {
      this.setItemInputValue('');
      this.toggleAddItemForm({
        issuableType: TYPE_ISSUE,
        toggleState: true,
      });
      this.showForm();
    },
    showCreateIssueForm() {
      this.toggleCreateIssueForm({
        toggleState: true,
      });
      this.showForm();
    },
    showAddEpicForm() {
      this.toggleAddItemForm({
        issuableType: TYPE_EPIC,
        toggleState: true,
      });
      this.showForm();
    },
    showCreateEpicForm() {
      this.toggleCreateEpicForm({
        toggleState: true,
      });
      this.showForm();
    },
    showForm() {
      this.$emit('showForm');
    },
  },
};
</script>

<template>
  <div
    v-if="parentIsEpic"
    class="gl-sm-pl-7 gl-mt-3 gl-flex gl-pl-0 gl-align-middle gl-leading-1 sm:gl-ml-auto sm:gl-mt-0 sm:gl-inline-flex"
  >
    <div class="js-button-container gl-grow gl-flex-col sm:gl-flex-row">
      <epic-actions-split-button
        :allow-sub-epics="allowSubEpics"
        class="js-add-epics-issues-button gl-w-full"
        @showAddIssueForm="showAddIssueForm"
        @showCreateIssueForm="showCreateIssueForm"
        @showAddEpicForm="showAddEpicForm"
        @showCreateEpicForm="showCreateEpicForm"
      />
    </div>
  </div>
</template>
