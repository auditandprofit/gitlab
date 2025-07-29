<script>
import CeBlobButtonGroup from '~/repository/components/header_area/blob_button_group.vue';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LockFileDropdownItem from 'ee_component/repository/components/header_area/lock_file_dropdown_item.vue';

export default {
  name: 'EEBlobButtonGroup',
  components: {
    CeBlobButtonGroup,
    LockFileDropdownItem,
  },
  mixins: [glFeatureFlagMixin()],
  inject: {
    blobInfo: {
      default: () => DEFAULT_BLOB_INFO.repository.blobs.nodes[0],
    },
  },
  props: {
    ...CeBlobButtonGroup.props,
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
  methods: {
    onShowForkSuggestion() {
      this.$emit('showForkSuggestion');
    },
  },
};
</script>

<template>
  <ce-blob-button-group v-bind="$props" @showForkSuggestion="onShowForkSuggestion">
    <template v-if="glFeatures.fileLocks" #lock-file-item>
      <lock-file-dropdown-item
        :name="blobInfo.name"
        :path="blobInfo.path"
        :project-path="projectPath"
        :user-permissions="userPermissions"
        :is-loading="isLoading"
        :can-create-lock="canCreateLock"
        :can-destroy-lock="canDestroyLock"
        :is-locked="isLocked"
      />
    </template>
  </ce-blob-button-group>
</template>
