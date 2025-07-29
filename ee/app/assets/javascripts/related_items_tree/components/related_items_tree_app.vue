<script>
import { GlLink, GlTooltipDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions, mapGetters } from 'vuex';
import { TYPE_EPIC, TYPE_ISSUE } from '~/issues/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__, sprintf } from '~/locale';
import AddItemForm from '~/related_issues/components/add_issuable_form.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { ITEM_TABS, OVERFLOW_AFTER, i18nConfidentialParent, treeTitle } from '../constants';
import CreateEpicForm from './create_epic_form.vue';
import CreateIssueForm from './create_issue_form.vue';
import RelatedItemsTreeBody from './related_items_tree_body.vue';
import RelatedItemsTreeHeaderActions from './related_items_tree_header_actions.vue';
import RelatedItemsTreeCount from './related_items_tree_count.vue';
import RelatedItemsTreeActions from './related_items_tree_actions.vue';
import RelatedItemsRoadmapApp from './related_items_roadmap_app.vue';
import SlotSwitch from './slot_switch.vue';
import TreeItemRemoveModal from './tree_item_remove_modal.vue';

const FORM_SLOTS = {
  addItem: 'addItem',
  createEpic: 'createEpic',
  createIssue: 'createIssue',
};

export default {
  OVERFLOW_AFTER,
  FORM_SLOTS,
  ITEM_TABS,
  i18nConfidentialParent,
  i18n: {
    emptyMessage: s__(
      "Epics|Link child issues and epics together to show that they're related, or that one blocks another.",
    ),
    helpLink: s__('Epics|Learn more about linking child issues and epics'),
    learnMore: __('Learn more'),
  },
  components: {
    GlLink,
    RelatedItemsTreeHeaderActions,
    RelatedItemsTreeCount,
    RelatedItemsTreeBody,
    RelatedItemsTreeActions,
    RelatedItemsRoadmapApp,
    AddItemForm,
    CreateEpicForm,
    TreeItemRemoveModal,
    CreateIssueForm,
    SlotSwitch,
    CrudComponent,
    HelpIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  data() {
    return {
      activeTab: ITEM_TABS.TREE,
    };
  },
  computed: {
    ...mapState([
      'parentItem',
      'itemsFetchInProgress',
      'itemsFetchResultEmpty',
      'itemAddInProgress',
      'itemAddFailure',
      'itemAddFailureType',
      'itemAddFailureMessage',
      'itemCreateInProgress',
      'showAddItemForm',
      'showCreateEpicForm',
      'showCreateIssueForm',
      'autoCompleteEpics',
      'autoCompleteIssues',
      'pendingReferences',
      'itemInputValue',
      'issuableType',
      'allowSubEpics',
    ]),
    ...mapGetters(['itemAutoCompleteSources', 'itemPathIdSeparator', 'directChildren']),
    disableContents() {
      return this.itemAddInProgress || this.itemCreateInProgress;
    },
    visibleForm() {
      if (this.showAddItemForm) {
        return FORM_SLOTS.addItem;
      }

      if (this.showCreateEpicForm) {
        return FORM_SLOTS.createEpic;
      }

      if (this.showCreateIssueForm) {
        return FORM_SLOTS.createIssue;
      }

      return null;
    },
    createIssuableText() {
      return sprintf(__('Create new confidential %{issuableType}'), {
        issuableType: this.issuableType,
      });
    },
    existingIssuableText() {
      return sprintf(__('Add existing confidential %{issuableType}'), {
        issuableType: this.issuableType,
      });
    },
    formSlots() {
      const { addItem, createEpic, createIssue } = this.$options.FORM_SLOTS;
      return [
        { name: addItem, value: this.existingIssuableText },
        { name: createEpic, value: this.createIssuableText },
        { name: createIssue, value: this.createIssuableText },
      ];
    },
    enableEpicsAutoComplete() {
      return this.issuableType === TYPE_EPIC && this.autoCompleteEpics;
    },
    enableIssuesAutoComplete() {
      return this.issuableType === TYPE_ISSUE && this.autoCompleteIssues;
    },
    helpUrl() {
      return helpPagePath('user/group/epics/manage_epics', {
        anchor: 'manage-issues-assigned-to-an-epic',
      });
    },
  },
  mounted() {
    this.fetchItems({
      parentItem: this.parentItem,
    });
  },
  updated() {
    if (this.itemAddFailure) {
      this.showForm();
    }
  },
  methods: {
    ...mapActions([
      'fetchItems',
      'toggleAddItemForm',
      'toggleCreateEpicForm',
      'toggleCreateIssueForm',
      'setPendingReferences',
      'addPendingReferences',
      'removePendingReference',
      'setItemInputValue',
      'addItem',
      'createItem',
      'createNewIssue',
    ]),
    getRawRefs(value) {
      return value.split(/\s+/).filter((ref) => ref.trim().length > 0);
    },
    handlePendingItemRemove(index) {
      this.removePendingReference(index);
    },
    handleAddItemFormInput({ untouchedRawReferences, touchedReference }) {
      this.addPendingReferences(untouchedRawReferences);
      this.setItemInputValue(`${touchedReference}`);
    },
    handleAddItemFormBlur(newValue) {
      this.addPendingReferences(this.getRawRefs(newValue));
      this.setItemInputValue('');
    },
    handleAddItemFormSubmit(event) {
      this.handleAddItemFormBlur(event.pendingReferences);

      if (this.pendingReferences.length > 0) {
        this.addItem();
        this.hideForm();
      }
    },
    handleCreateEpicFormSubmit({ value, groupFullPath }) {
      this.createItem({
        itemTitle: value,
        groupFullPath,
      });
      this.hideForm();
    },
    handleAddItemFormCancel() {
      this.toggleAddItemForm({ toggleState: false });
      this.setPendingReferences([]);
      this.setItemInputValue('');
      this.hideForm();
    },
    handleCreateEpicFormCancel() {
      this.toggleCreateEpicForm({ toggleState: false });
      this.setItemInputValue('');
      this.hideForm();
    },
    cancelNewIssue() {
      this.toggleCreateIssueForm({ toggleState: false });
      this.hideForm();
    },
    handleTabChange(value) {
      this.activeTab = value;
    },
    showForm() {
      this.$refs.relatedItemsTreeCrud.showForm();
    },
    hideForm() {
      this.$refs.relatedItemsTreeCrud.hideForm();
    },
  },
  treeTitle,
};
</script>

<template>
  <div class="related-items-tree-container">
    <crud-component
      ref="relatedItemsTreeCrud"
      :title="allowSubEpics ? __('Child issues and epics') : $options.treeTitle[parentItem.type]"
      class="related-items-tree !gl-mt-4"
      :class="{ 'disabled-content': disableContents }"
      title-class="gl-flex-wrap"
      :body-class="{ '!gl-m-0': !itemsFetchInProgress && !itemsFetchResultEmpty }"
      :is-loading="itemsFetchInProgress"
      is-collapsible
      data-testid="legacy-related-items-tree"
    >
      <template #count>
        <related-items-tree-count />
      </template>

      <template #actions>
        <related-items-tree-header-actions @showForm="showForm" />
      </template>

      <template #form>
        <slot-switch
          :active-slot-names="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ [
            visibleForm,
          ] /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
          :class="{ 'gl-show-field-errors': itemAddFailure }"
          data-testid="add-item-form"
        >
          <template #[$options.FORM_SLOTS.addItem]>
            <add-item-form
              :issuable-type="issuableType"
              :input-value="itemInputValue"
              :is-submitting="itemAddInProgress"
              :pending-references="pendingReferences"
              :auto-complete-sources="itemAutoCompleteSources"
              :auto-complete-epics="enableEpicsAutoComplete"
              :auto-complete-issues="enableIssuesAutoComplete"
              :path-id-separator="itemPathIdSeparator"
              :has-error="itemAddFailure"
              :item-add-failure-type="itemAddFailureType"
              :item-add-failure-message="itemAddFailureMessage"
              :confidential="parentItem.confidential"
              @pendingIssuableRemoveRequest="handlePendingItemRemove"
              @addIssuableFormInput="handleAddItemFormInput"
              @addIssuableFormBlur="handleAddItemFormBlur"
              @addIssuableFormSubmit="handleAddItemFormSubmit"
              @addIssuableFormCancel="handleAddItemFormCancel"
            />
          </template>
          <template #[$options.FORM_SLOTS.createEpic]>
            <create-epic-form
              :is-submitting="itemCreateInProgress"
              @createEpicFormSubmit="handleCreateEpicFormSubmit"
              @createEpicFormCancel="handleCreateEpicFormCancel"
            />
          </template>
          <template #[$options.FORM_SLOTS.createIssue]>
            <create-issue-form @cancel="cancelNewIssue" @submit="createNewIssue" />
          </template>
        </slot-switch>
      </template>

      <template v-if="itemsFetchResultEmpty" #empty>
        {{ $options.i18n.emptyMessage }}
        <gl-link
          :href="helpUrl"
          target="_blank"
          data-testid="help-link"
          :aria-label="$options.i18n.helpLink"
        >
          {{ $options.i18n.learnMore }}.
        </gl-link>
      </template>

      <template #default>
        <slot-switch
          v-if="visibleForm && parentItem.confidential"
          :active-slot-names="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ [
            visibleForm,
          ] /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
          class="gl-p-5 gl-pb-0"
        >
          <template v-for="slot in formSlots" #[slot.name]>
            <h6 :key="slot.name">
              {{ slot.value }}
              <help-icon
                v-gl-tooltip.hover
                :title="$options.i18nConfidentialParent[parentItem.type]"
              />
            </h6>
          </template>
        </slot-switch>
        <related-items-tree-actions :active-tab="activeTab" @tab-change="handleTabChange" />
        <related-items-tree-body
          v-if="activeTab === $options.ITEM_TABS.TREE"
          :parent-item="parentItem"
          :children="directChildren"
          data-testid="related-items-tree"
        />
        <related-items-roadmap-app v-if="activeTab === $options.ITEM_TABS.ROADMAP" />
        <tree-item-remove-modal />
      </template>
    </crud-component>
  </div>
</template>
