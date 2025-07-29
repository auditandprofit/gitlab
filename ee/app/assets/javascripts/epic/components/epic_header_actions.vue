<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlDisclosureDropdownGroup,
  GlModalDirective,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { keysFor, ISSUABLE_EDIT_DESCRIPTION } from '~/behaviors/shortcuts/keybindings';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { sanitize } from '~/lib/dompurify';
import { TYPE_EPIC } from '~/issues/constants';
import DeleteIssueModal from '~/issues/show/components/delete_issue_modal.vue';
import issuesEventHub from '~/issues/show/event_hub';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import SidebarSubscriptionsWidget from '~/sidebar/components/subscriptions/sidebar_subscriptions_widget.vue';
import AbuseCategorySelector from '~/abuse_reports/components/abuse_category_selector.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import toast from '~/vue_shared/plugins/global_toast';

export default {
  TYPE_EPIC,
  deleteModalId: 'delete-modal-id',
  i18n: {
    copyReferenceText: __('Copy reference'),
    deleteButtonText: __('Delete epic'),
    dropdownText: __('Epic actions'),
    edit: __('Edit'),
    editTitleAndDescription: __('Edit title and description'),
    newEpicText: __('New epic'),
    reportAbuse: __('Report abuse'),
  },
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  components: {
    DeleteIssueModal,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlDisclosureDropdownGroup,
    SidebarSubscriptionsWidget,
    AbuseCategorySelector,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['fullPath', 'iid'],
  data() {
    return {
      isReportAbuseDrawerOpen: false,
      isDesktopDropdownVisible: false,
    };
  },
  computed: {
    ...mapState([
      'author',
      'canCreate',
      'canUpdate',
      'canDestroy',
      'newEpicWebUrl',
      'webUrl',
      'reference',
    ]),
    ...mapGetters(['isEpicOpen', 'isEpicAuthor']),
    actionButtonText() {
      return this.isEpicOpen ? __('Close epic') : __('Reopen epic');
    },
    showNotificationToggle() {
      return isLoggedIn();
    },
    newEpicDropdownItem() {
      return {
        text: this.$options.i18n.newEpicText,
        href: this.newEpicWebUrl,
      };
    },
    copyReferenceDropdownItem() {
      return {
        text: this.$options.i18n.copyReferenceText,
        action: this.closeDropdownAfterAction.bind(this, this.copyReference),
        extraAttrs: {
          'data-clipboard-text': this.reference,
          class: 'js-copy-reference',
        },
      };
    },
    toggleEpicStatusDropdownItem() {
      return {
        text: this.actionButtonText,
        action: this.closeDropdownAfterAction.bind(
          this,
          this.toggleEpicStatus.bind(this, this.isEpicOpen),
        ),
        extraAttrs: {
          'data-testid': 'toggle-status-button',
        },
      };
    },
    actionsDropdownGroupMobile() {
      const items = [];

      if (this.canUpdate) {
        items.push({
          text: this.$options.i18n.edit,
          action: this.closeDropdownAfterAction.bind(this, this.editEpic),
        });
      }

      if (this.canCreate) {
        items.push(this.newEpicDropdownItem);
      }

      if (this.canUpdate) {
        items.push(this.toggleEpicStatusDropdownItem);
      }

      items.push(this.copyReferenceDropdownItem);

      return { items };
    },
    actionsDropdownGroupDesktop() {
      const items = [];

      if (this.canUpdate) {
        items.push(this.toggleEpicStatusDropdownItem);
      }

      if (this.canCreate) {
        items.push(this.newEpicDropdownItem);
      }

      items.push(this.copyReferenceDropdownItem);

      return { items };
    },
    canReportAbuseToAdmin() {
      return !this.isEpicAuthor;
    },
    authorId() {
      return this.author?.id;
    },
    editShortcutKey() {
      return shouldDisableShortcuts() ? null : keysFor(ISSUABLE_EDIT_DESCRIPTION)[0];
    },
    editTooltip() {
      const description = this.$options.i18n.editTitleAndDescription;
      const key = this.editShortcutKey;
      return shouldDisableShortcuts()
        ? description
        : sanitize(`${description} <kbd class="flat gl-ml-1" aria-hidden=true>${key}</kbd>`);
    },
    showDropdownTooltip() {
      return !this.isDesktopDropdownVisible ? this.$options.i18n.dropdownText : '';
    },
  },
  methods: {
    ...mapActions(['toggleEpicStatus']),
    closeDropdownAfterAction(action) {
      action();
      this.closeActionsDropdown();
    },
    copyReference() {
      toast(__('Reference copied'));
    },
    editEpic() {
      issuesEventHub.$emit('open.form');
    },
    closeActionsDropdown() {
      this.$refs.epicActionsDropdownMobile?.close();
      this.$refs.epicActionsDropdownDesktop?.close();
    },
    toggleReportAbuseDrawer(isOpen) {
      this.isReportAbuseDrawerOpen = isOpen;
    },
    showDesktopDropdown() {
      this.isDesktopDropdownVisible = true;
    },
    hideDesktopDropdown() {
      this.isDesktopDropdownVisible = false;
    },
  },
};
</script>

<template>
  <div class="gl-contents">
    <gl-disclosure-dropdown
      ref="epicActionsDropdownMobile"
      class="gl-mt-3 gl-block gl-w-full md:!gl-hidden"
      category="secondary"
      :auto-close="false"
      toggle-class="gl-w-full"
      :toggle-text="$options.i18n.dropdownText"
    >
      <gl-disclosure-dropdown-group
        v-if="showNotificationToggle && !glFeatures.notificationsTodosButtons"
      >
        <sidebar-subscriptions-widget
          :iid="String(iid)"
          :full-path="fullPath"
          :issuable-type="$options.TYPE_EPIC"
        />
      </gl-disclosure-dropdown-group>

      <gl-disclosure-dropdown-group
        data-testid="actions-dropdown-mobile"
        :group="actionsDropdownGroupMobile"
        :bordered="showNotificationToggle && !glFeatures.notificationsTodosButtons"
      />

      <gl-disclosure-dropdown-group v-if="canReportAbuseToAdmin" bordered>
        <gl-disclosure-dropdown-item @action="toggleReportAbuseDrawer(true)">
          <template #list-item>
            {{ $options.i18n.reportAbuse }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>

      <gl-disclosure-dropdown-group v-if="canDestroy">
        <gl-disclosure-dropdown-item v-gl-modal="$options.deleteModalId" variant="danger">
          <template #list-item>
            {{ $options.i18n.deleteButtonText }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>

    <gl-button
      v-if="canUpdate"
      v-gl-tooltip.viewport.html
      :title="editTooltip"
      :aria-label="$options.i18n.editTitleAndDescription"
      :aria-keyshortcuts="editShortcutKey"
      category="secondary"
      class="js-issuable-edit gl-hidden md:gl-block"
      @click="editEpic"
    >
      {{ $options.i18n.edit }}
    </gl-button>

    <gl-disclosure-dropdown
      ref="epicActionsDropdownDesktop"
      v-gl-tooltip="showDropdownTooltip"
      class="gl-hidden md:gl-block"
      placement="bottom-end"
      :auto-close="false"
      data-testid="desktop-dropdown"
      :toggle-text="$options.i18n.dropdownText"
      text-sr-only
      icon="ellipsis_v"
      category="tertiary"
      no-caret
      @shown="showDesktopDropdown"
      @hidden="hideDesktopDropdown"
    >
      <gl-disclosure-dropdown-group
        v-if="showNotificationToggle && !glFeatures.notificationsTodosButtons"
      >
        <sidebar-subscriptions-widget
          :iid="String(iid)"
          :full-path="fullPath"
          :issuable-type="$options.TYPE_EPIC"
        />
      </gl-disclosure-dropdown-group>

      <gl-disclosure-dropdown-group
        data-testid="actions-dropdown-desktop"
        :group="actionsDropdownGroupDesktop"
        :bordered="showNotificationToggle && !glFeatures.notificationsTodosButtons"
      />

      <gl-disclosure-dropdown-group v-if="canReportAbuseToAdmin" bordered>
        <gl-disclosure-dropdown-item @action="toggleReportAbuseDrawer(true)">
          <template #list-item>
            {{ $options.i18n.reportAbuse }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>

      <gl-disclosure-dropdown-group v-if="canDestroy">
        <gl-disclosure-dropdown-item v-gl-modal="$options.deleteModalId" variant="danger">
          <template #list-item>
            {{ $options.i18n.deleteButtonText }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>

    <delete-issue-modal
      :issue-type="$options.TYPE_EPIC"
      :modal-id="$options.deleteModalId"
      :title="$options.i18n.deleteButtonText"
    />

    <abuse-category-selector
      v-if="isReportAbuseDrawerOpen"
      :reported-user-id="authorId"
      :reported-from-url="webUrl"
      :show-drawer="isReportAbuseDrawerOpen"
      @close-drawer="toggleReportAbuseDrawer(false)"
    />
  </div>
</template>
