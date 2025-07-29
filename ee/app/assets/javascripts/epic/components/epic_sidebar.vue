<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters, mapActions } from 'vuex';

import SidebarAncestorsWidget from 'ee_component/sidebar/components/ancestors_tree/sidebar_ancestors_widget.vue';

import { TYPENAME_EPIC } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_EPIC, WORKSPACE_GROUP } from '~/issues/constants';
import { newDate } from '~/lib/utils/datetime_utility';
import notesEventHub from '~/notes/event_hub';
import SubscriptionsWidget from '~/sidebar/components/subscriptions/sidebar_subscriptions_widget.vue';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import SidebarDateWidget from '~/sidebar/components/date/sidebar_date_widget.vue';
import SidebarParticipantsWidget from '~/sidebar/components/participants/sidebar_participants_widget.vue';
import SidebarTodoWidget from '~/sidebar/components/todo_toggle/sidebar_todo_widget.vue';
import sidebarEventHub from '~/sidebar/event_hub';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import ColorSelectDropdown from '~/vue_shared/components/color_select_dropdown/color_select_root.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

import epicUtils from '../utils/epic_utils';
import SidebarHeader from './sidebar_items/sidebar_header.vue';

export default {
  WORKSPACE_GROUP,
  components: {
    SidebarHeader,
    SidebarDateWidget,
    SidebarAncestorsWidget,
    SidebarParticipantsWidget,
    SidebarConfidentialityWidget,
    SidebarTodoWidget,
    SubscriptionsWidget,
    LabelsSelectWidget,
    ColorSelectDropdown,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['iid'],
  data() {
    return {
      sidebarExpandedOnClick: false,
      minDate: null,
      maxDate: null,
    };
  },
  computed: {
    ...mapState([
      'canUpdate',
      'allowSubEpics',
      'sidebarCollapsed',
      'fullPath',
      'epicId',
      'epicsWebUrl',
    ]),
    ...mapGetters(['isUserSignedIn']),
    issuableType() {
      return TYPE_EPIC;
    },
    fullEpicId() {
      return convertToGraphQLId(TYPENAME_EPIC, this.epicId);
    },
  },
  mounted() {
    this.toggleSidebarFlag(epicUtils.getCollapsedGutter());
    this.fetchEpicDetails();
    sidebarEventHub.$on('updateIssuableConfidentiality', this.updateEpicConfidentiality);
  },
  beforeDestroy() {
    sidebarEventHub.$off('updateIssuableConfidentiality', this.updateEpicConfidentiality);
  },
  methods: {
    ...mapActions([
      'fetchEpicDetails',
      'toggleSidebar',
      'toggleSidebarFlag',
      'updateConfidentialityOnIssuable',
    ]),
    updateEpicConfidentiality(confidential) {
      notesEventHub.$emit('notesApp.updateIssuableConfidentiality', confidential);
    },
    handleSidebarToggle() {
      if (this.sidebarCollapsed) {
        this.sidebarExpandedOnClick = true;
        this.toggleSidebar({ sidebarCollapsed: true });
      } else if (this.sidebarExpandedOnClick) {
        this.sidebarExpandedOnClick = false;
        this.toggleSidebar({ sidebarCollapsed: false });
      }
    },
    updateMinDate(value) {
      this.minDate = value ? newDate(value) : null;
    },
    updateMaxDate(value) {
      this.maxDate = value ? newDate(value) : null;
    },
  },
};
</script>

<template>
  <aside
    :class="{
      'right-sidebar-expanded': !sidebarCollapsed,
      'right-sidebar-collapsed': sidebarCollapsed,
    }"
    :data-signed-in="isUserSignedIn"
    data-always-show-toggle
    class="right-sidebar epic-sidebar"
    :aria-label="__('Epic')"
  >
    <div class="issuable-sidebar js-issuable-update gl-bg-inherit">
      <sidebar-header :sidebar-collapsed="sidebarCollapsed">
        <sidebar-todo-widget
          v-if="isUserSignedIn"
          :class="{ 'btn-icon': glFeatures.notificationsTodosButtons }"
          :issuable-id="fullEpicId"
          :issuable-iid="String(iid)"
          :full-path="fullPath"
          :issuable-type="issuableType"
        />
        <subscriptions-widget
          v-if="glFeatures.notificationsTodosButtons"
          class="btn-icon"
          :iid="String(iid)"
          :full-path="fullPath"
          :issuable-type="issuableType"
          :class="{ 'gl-ml-2': !sidebarCollapsed }"
          @expandSidebar="handleSidebarToggle"
        />
      </sidebar-header>
      <sidebar-date-widget
        :iid="String(iid)"
        :full-path="fullPath"
        date-type="startDate"
        :issuable-type="issuableType"
        can-inherit
        data-testid="start-date"
        :max-date="maxDate"
        @startDateUpdated="updateMinDate"
      />
      <sidebar-date-widget
        :iid="String(iid)"
        :full-path="fullPath"
        date-type="dueDate"
        :issuable-type="issuableType"
        can-inherit
        data-testid="due-date"
        :min-date="minDate"
        @dueDateUpdated="updateMaxDate"
      />
      <labels-select-widget
        class="block labels js-labels-block"
        :iid="String(iid)"
        :full-path="fullPath"
        :allow-label-remove="canUpdate"
        allow-multiselect
        :labels-filter-base-path="epicsWebUrl"
        variant="sidebar"
        issuable-type="epic"
        workspace-type="group"
        :attr-workspace-path="fullPath"
        :label-create-type="$options.WORKSPACE_GROUP"
        data-testid="labels-select"
        @toggleCollapse="handleSidebarToggle"
      >
        {{ __('None') }}
      </labels-select-widget>

      <color-select-dropdown
        class="block colors js-colors-block"
        :allow-edit="canUpdate"
        :iid="String(iid)"
        :full-path="fullPath"
        workspace-type="group"
        issuable-type="epic"
        variant="sidebar"
        data-testid="colors-select"
      >
        {{ __('None') }}
      </color-select-dropdown>
      <sidebar-confidentiality-widget
        :iid="String(iid)"
        :full-path="fullPath"
        :issuable-type="issuableType"
        @closeForm="handleSidebarToggle"
        @expandSidebar="handleSidebarToggle"
        @confidentialityUpdated="updateConfidentialityOnIssuable($event)"
      />
      <sidebar-ancestors-widget
        v-if="allowSubEpics"
        :iid="String(iid)"
        :full-path="fullPath"
        :issuable-type="issuableType"
      />
      <sidebar-participants-widget
        :iid="String(iid)"
        :full-path="fullPath"
        :issuable-type="issuableType"
        @toggleSidebar="handleSidebarToggle"
      />
    </div>
  </aside>
</template>
