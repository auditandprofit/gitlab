<script>
import { GlAlert, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import WorkspaceEmptyState from './empty_state.vue';

export const i18n = {
  learnMoreHelpLink: __('Learn more'),
  heading: s__('Workspaces|Workspaces'),
};

const workspacesHelpPath = helpPagePath('user/workspace/_index.md');

export default {
  components: {
    GlAlert,
    GlLink,
    WorkspaceEmptyState,
  },
  props: {
    empty: {
      type: Boolean,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
    newWorkspacePath: {
      type: String,
      required: false,
      default: '',
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    clearError() {
      this.$emit('error', '');
    },
  },
  i18n,
  workspacesHelpPath,
};
</script>
<template>
  <div>
    <gl-alert v-if="error" variant="danger" @dismiss="clearError">
      {{ error }}
    </gl-alert>
    <workspace-empty-state v-if="!loading && empty" :new-workspace-path="newWorkspacePath" />
    <template v-else>
      <div data-testid="workspaces-list-header" class="gl-flex gl-items-center gl-justify-between">
        <div class="gl-flex gl-items-center">
          <h2>{{ $options.i18n.heading }}</h2>
        </div>
        <div class="gl-flex gl-flex-col gl-items-center md:gl-flex-row">
          <gl-link
            class="workspace-list-link gl-mr-5 gl-hidden sm:gl-block"
            :href="$options.workspacesHelpPath"
            >{{ $options.i18n.learnMoreHelpLink }}</gl-link
          >
          <slot name="header"></slot>
        </div>
      </div>
      <slot name="workspaces-list"></slot>
    </template>
  </div>
</template>
