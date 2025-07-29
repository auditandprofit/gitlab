<script>
import { GlButton, GlTooltip, GlModal, GlModalDirective } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';

export default {
  name: 'LockDirectoryButton',
  i18n: {
    fetchError: __('An error occurred while fetching lock information, please try again.'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
  },
  modal: {
    modalTitle: __('Lock directory?'),
    actionPrimary: {
      text: __('Ok'),
      attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
  components: {
    GlButton,
    GlModal,
    GlTooltip,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    projectInfo: {
      query: projectInfoQuery,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update({ project }) {
        const allPathLocks = project?.pathLocks?.nodes?.map((lock) => this.mapPathLocks(lock));
        this.pathLock =
          allPathLocks?.find(
            (lock) =>
              this.isDownstreamLock(lock) || this.isUpstreamLock(lock) || this.isExactLock(lock),
          ) || {};
        this.projectUserPermissions = project?.userPermissions || {
          ...DEFAULT_BLOB_INFO.userPermissions,
          createPathLock: false,
        };
      },
      result() {
        this.$emit('lockedDirectory', {
          isLocked: this.hasPathLocks && this.isLocked,
          lockAuthor: this.pathLock.user?.name,
        });
      },
      error(error) {
        logError(`Unexpected error while fetching projectInfo query`, error);
        this.onFetchError(error);
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    currentUser: {
      query: currentUserQuery,
      update({ currentUser }) {
        this.user = { ...currentUser };
      },
      error(error) {
        logError(`Unexpected error while fetching currentUser query`, error);
        this.onFetchError(error);
      },
    },
  },
  data() {
    return {
      isUpdating: false,
      pathLock: {},
      user: {},
      projectUserPermissions: {},
    };
  },
  computed: {
    showLockButton() {
      return Boolean(this.glFeatures.fileLocks && this.user?.id);
    },
    isLoading() {
      return this.$apollo?.queries.projectInfo.loading;
    },
    isLocked() {
      return this.pathLock.isExactLock || this.pathLock.isUpstreamLock;
    },
    hasPathLocks() {
      return Object.keys(this.pathLock).length > 0;
    },
    locker() {
      return this.pathLock.user?.name || this.pathLock.user?.username;
    },
    buttonLabel() {
      return this.isLocked ? __('Unlock') : __('Lock');
    },
    buttonState() {
      return this.isLocked ? 'unlock' : 'lock';
    },
    isLockAuthor() {
      return this.pathLock.user?.id === this.user.id;
    },
    canCreatePathLock() {
      return this.projectUserPermissions.createPathLock;
    },
    canDestroyExactLock() {
      return this.pathLock?.userPermissions.destroyPathLock;
    },
    isDisabled() {
      return (
        this.pathLock.isUpstreamLock ||
        this.pathLock.isDownstreamLock ||
        (this.pathLock.isExactLock && !this.canDestroyExactLock) ||
        !this.canCreatePathLock ||
        this.isUpdating
      );
    },
    getExactLockTooltip() {
      if (!this.canCreatePathLock) {
        return sprintf(__('Locked by %{locker}. You do not have permission to unlock this'), {
          locker: this.locker,
        });
      }
      return this.isLockAuthor ? '' : sprintf(__('Locked by %{locker}'), { locker: this.locker });
    },
    getUpstreamLockTooltip() {
      const additionalPhrase = this.canCreatePathLock
        ? __('Unlock that directory in order to unlock this')
        : __('You do not have permission to unlock it');
      return sprintf(__('%{locker} has a lock on "%{path}". %{additionalPhrase}'), {
        locker: this.locker,
        path: this.pathLock.path,
        additionalPhrase,
      });
    },
    getDownstreamLockTooltip() {
      const additionalPhrase = this.canCreatePathLock
        ? __('Unlock this in order to proceed')
        : __('You do not have permission to unlock it');
      return sprintf(
        __(
          'This directory cannot be locked while %{locker} has a lock on "%{path}". %{additionalPhrase}',
        ),
        {
          locker: this.locker,
          path: this.pathLock.path,
          additionalPhrase,
        },
      );
    },
    tooltipText() {
      if (!this.canCreatePathLock && !this.hasPathLocks) {
        return __('You do not have permission to lock this');
      }
      if (this.pathLock.isDownstreamLock) {
        return this.getDownstreamLockTooltip;
      }
      if (this.pathLock.isUpstreamLock) {
        return this.getUpstreamLockTooltip;
      }
      if (this.pathLock.isExactLock) {
        return this.getExactLockTooltip;
      }
      return '';
    },
    modalId() {
      return `lock-directory-modal-${this.path.replaceAll('/', '-')}`;
    },
    modalContent() {
      return this.isLocked
        ? __('Are you sure you want to unlock this directory?')
        : __('Are you sure you want to lock this directory?');
    },
  },
  watch: {
    async path() {
      try {
        await this.$apollo.queries.projectInfo.refetch();
      } catch (error) {
        logError(`Unexpected error while refetch projectInfo query`, error);
        this.onFetchError(error);
      }
    },
  },
  methods: {
    onFetchError(error) {
      Sentry.captureException(error);
      createAlert({ message: this.$options.i18n.fetchError });
    },
    isExactLock(lock) {
      return lock.path === this.path;
    },
    isUpstreamLock(lock) {
      return this.path.startsWith(lock.path) && this.path !== lock.path;
    },
    isDownstreamLock(lock) {
      return lock.path.startsWith(this.path) && this.path !== lock.path;
    },
    mapPathLocks(lock) {
      return {
        ...lock,
        isExactLock: this.isExactLock(lock),
        isUpstreamLock: this.isUpstreamLock(lock),
        isDownstreamLock: this.isDownstreamLock(lock),
      };
    },
    toggleLock() {
      const locked = !this.isLocked;
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
          window.location.reload();
        })
        .catch((error) => {
          logError(`Unexpected error while Locking/Unlocking path`, error);
          Sentry.captureException(error);
          createAlert({ message: this.$options.i18n.mutationError, error, captureError: true });
        });
    },
  },
};
</script>
<template>
  <span
    v-if="showLockButton"
    ref="buttonWrapper"
    class="btn-group"
    :class="
      glFeatures.repositoryFileTreeBrowser ? 'gl-w-full md:gl-w-auto' : 'gl-w-full sm:gl-w-auto'
    "
  >
    <gl-tooltip v-if="tooltipText" :target="() => $refs.buttonWrapper">
      {{ tooltipText }}
    </gl-tooltip>
    <gl-button
      v-gl-modal-directive="modalId"
      :loading="isLoading"
      :disabled="isDisabled"
      class="path-lock js-path-lock"
      :data-testid="isDisabled ? 'disabled-lock-button' : 'lock-button'"
      :data-state="buttonState"
    >
      {{ buttonLabel }}
    </gl-button>
    <gl-modal
      size="sm"
      :modal-id="modalId"
      :title="$options.modal.modalTitle"
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="toggleLock"
    >
      <p>{{ modalContent }}</p>
    </gl-modal>
  </span>
</template>
