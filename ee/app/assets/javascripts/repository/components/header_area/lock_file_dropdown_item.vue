<script>
import Vue from 'vue';
import { GlDisclosureDropdownItem, GlModal, GlToast } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, __ } from '~/locale';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';

Vue.use(GlToast);

export default {
  i18n: {
    lock: __('Lock'),
    unlock: __('Unlock'),
    modalTitle: __('Lock file?'),
    actionCancel: __('Cancel'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
  },
  components: {
    GlDisclosureDropdownItem,
    GlModal,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    canCreateLock: {
      type: Boolean,
      required: true,
    },
    canDestroyLock: {
      type: Boolean,
      required: true,
    },
    isLocked: {
      type: Boolean,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isUpdating: false,
      isModalVisible: false,
      locked: false,
    };
  },
  computed: {
    lockButtonTitle() {
      return this.isLocked ? this.$options.i18n.unlock : this.$options.i18n.lock;
    },
    lockConfirmText() {
      return sprintf(__('Are you sure you want to %{action} %{name}?'), {
        action: this.lockButtonTitle.toLowerCase(),
        name: this.name,
      });
    },
    lockFileItem() {
      return {
        text: this.lockButtonTitle,
        extraAttrs: {
          'data-testid': 'lock-file-dropdown-item',
          disabled:
            !this.canCreateLock ||
            (this.isLocked && !this.canDestroyLock) ||
            this.isLoading ||
            this.isUpdating,
        },
      };
    },
    modalActions() {
      return {
        primary: {
          text: this.lockButtonTitle,
          attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
        },
        cancel: {
          text: this.$options.i18n.actionCancel,
        },
      };
    },
  },
  watch: {
    isLocked: {
      immediate: true,
      handler(val) {
        this.locked = val;
      },
    },
  },
  methods: {
    hideModal() {
      this.isModalVisible = false;
    },
    showModal() {
      if (this.canCreateLock) {
        this.isModalVisible = true;
      }
    },
    toggleLock() {
      const locked = !this.locked;
      this.isUpdating = true;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock: locked,
          },
        })
        .then(() => {
          this.$toast.show(locked ? __('The file is locked.') : __('The file is unlocked.'));
          this.locked = locked;
        })
        .catch((error) => {
          createAlert({ message: this.$options.i18n.mutationError, captureError: true, error });
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown-item :item="lockFileItem" @action="showModal" />
    <gl-modal
      modal-id="lock-file-modal"
      :visible="isModalVisible"
      :title="$options.i18n.modalTitle"
      :action-primary="modalActions.primary"
      :action-cancel="modalActions.cancel"
      @primary="toggleLock"
      @hide="hideModal"
    >
      <p>
        {{ lockConfirmText }}
      </p>
    </gl-modal>
  </div>
</template>
