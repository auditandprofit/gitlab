<script>
import {
  GlButton,
  GlLink,
  GlModal,
  GlAvatar,
  GlAvatarLink,
  GlLoadingIcon,
  GlCard,
} from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'DuoWorkflowSettings',
  components: {
    GlButton,
    GlLink,
    GlModal,
    GlAvatar,
    GlAvatarLink,
    GlLoadingIcon,
    GlCard,
  },
  inject: [
    'duoWorkflowEnabled',
    'duoWorkflowServiceAccount',
    'duoWorkflowSettingsPath',
    'redirectPath',
    'duoWorkflowDisablePath',
  ],
  data() {
    return {
      showConfirmModal: false,
      isLoading: false,
    };
  },
  computed: {
    serviceAccountHelpPath() {
      return helpPagePath('user/duo_agent_platform/security');
    },
  },
  methods: {
    enableWorkflow() {
      this.isLoading = true;

      axios
        .post(this.duoWorkflowSettingsPath)
        .then(({ data }) => {
          const username = data?.service_account?.username;

          visitUrlWithAlerts(this.redirectPath, [
            {
              id: 'duo-workflow-successfully-enabled',
              message: username
                ? sprintf(
                    s__(
                      'AiPowered|GitLab Duo Agent Platform is now on for the instance and the service account (%{accountId}) was created. To use Agent Platform in your groups, you must turn on AI features for specific groups.',
                    ),
                    {
                      accountId: `@${username}`,
                    },
                  )
                : s__(
                    'AiPowered|GitLab Duo Agent Platform is now on for the instance. To use Agent Platform in your groups, you must turn on AI features for specific groups.',
                  ),
              variant: 'success',
            },
          ]);
        })
        .catch((error) => {
          createAlert({
            message:
              error.response?.data?.message ||
              s__('AiPowered|Failed to enable GitLab Duo Agent Platform.'),
            captureError: true,
            error,
          });
          this.isLoading = false;
        });
    },

    disableWorkflow() {
      this.showConfirmModal = false;
      this.isLoading = true;

      axios
        .post(this.duoWorkflowDisablePath)
        .then(({ status }) => {
          if (status === 200) {
            visitUrlWithAlerts(this.redirectPath, [
              {
                id: 'duo-workflow-successfully-disabled',
                message: s__(
                  'AiPowered|GitLab Duo Agent Platform has successfully been turned off.',
                ),
                variant: 'success',
              },
            ]);
          }
        })
        .catch((error) => {
          createAlert({
            message:
              error.response?.data?.message ||
              s__('AiPowered|Failed to disable GitLab Duo Agent Platform.'),
            captureError: true,
            error,
          });
          this.isLoading = false;
        });
    },

    showDisableConfirmation() {
      this.showConfirmModal = true;
    },
    hideDisableConfirmation() {
      this.showConfirmModal = false;
    },
  },
};
</script>

<template>
  <div>
    <gl-card
      header-class="gl-bg-transparent gl-border-none gl-pb-0"
      footer-class="gl-bg-transparent gl-border-none gl-flex-end"
      class="gl-mt-5 gl-justify-between"
    >
      <template #default>
        <h2 class="gl-heading-3 gl-mb-3 gl-font-bold">
          {{ s__('AiPowered|GitLab Duo Agent Platform') }}
        </h2>

        <h3 class="gl-font-lg gl-mb-3">
          {{ duoWorkflowEnabled ? __('On') : __('Off') }}
        </h3>

        <template v-if="duoWorkflowEnabled">
          <div class="gl-border-t gl-py-3">
            <div class="gl-flex gl-items-center gl-gap-2" data-testid="service-account">
              <span>{{ __('Account:') }}</span>
              <gl-avatar-link
                :href="duoWorkflowServiceAccount.webUrl"
                :title="duoWorkflowServiceAccount.name"
                class="js-user-link gl-text-subtle"
                :data-user-id="duoWorkflowServiceAccount.id"
              >
                <gl-avatar
                  :src="duoWorkflowServiceAccount.avatarUrl"
                  :size="24"
                  :entity-name="duoWorkflowServiceAccount.name"
                  class="gl-mr-1"
                />
              </gl-avatar-link>
              <span class="gl-mr-1 gl-font-bold">{{ duoWorkflowServiceAccount.name }}</span>
              <span class="gl-text-gray-500">{{ duoWorkflowServiceAccount.username }}</span>
            </div>
          </div>
        </template>

        <template v-else>
          <div class="gl-border-b gl-py-3">
            <p class="gl-mb-0">
              {{
                s__(
                  'AiPowered|GitLab Duo Agent Platform is an AI-native coding agent in the Visual Studio Code (VS Code) IDE.',
                )
              }}
            </p>
          </div>
        </template>
      </template>

      <template #footer>
        <div v-if="duoWorkflowEnabled">
          <gl-button
            variant="danger"
            data-testid="disable-workflow-button"
            :disabled="isLoading"
            @click="showDisableConfirmation"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ s__('AiPowered|Turn off GitLab Duo Agent Platform') }}
          </gl-button>
        </div>

        <div v-else>
          <gl-button
            variant="confirm"
            category="primary"
            data-testid="enable-workflow-button"
            :disabled="isLoading"
            @click="enableWorkflow"
          >
            <gl-loading-icon v-if="isLoading" inline size="sm" class="gl-mr-2" />
            {{ s__('AiPowered|Turn on GitLab Duo Agent Platform') }}
          </gl-button>

          <p class="gl-mb-0 gl-mt-5">
            {{
              s__(
                'AiPowered|When you turn on GitLab Duo Agent Platform, a service account is created.',
              )
            }}
            <gl-link
              :href="serviceAccountHelpPath"
              class="gl-ml-1"
              data-testid="service-account-link"
            >
              {{ s__('AiPowered|What is the Duo Agent Platform service account?') }}
            </gl-link>
          </p>
        </div>
      </template>
    </gl-card>

    <gl-modal
      :visible="showConfirmModal"
      :title="s__('AiPowered|Are you sure you want to turn off GitLab Duo Agent Platform?')"
      modal-id="disable-workflow-modal"
      size="sm"
      @primary="disableWorkflow"
      @cancel="hideDisableConfirmation"
      @close="hideDisableConfirmation"
    >
      <p>
        {{
          s__(
            'AiPowered|When you turn off GitLab Duo Agent Platform, users can no longer use it to solve coding tasks. Are you sure?',
          )
        }}
      </p>
      <template #modal-footer>
        <gl-button class="js-cancel" data-testid="cancel-button" @click="hideDisableConfirmation">
          {{ __('Cancel') }}
        </gl-button>
        <gl-button
          variant="danger"
          class="js-danger"
          data-testid="confirm-disable-button"
          @click="disableWorkflow"
        >
          {{ s__('AiPowered|Turn off GitLab Duo Agent Platform') }}
        </gl-button>
      </template>
    </gl-modal>
  </div>
</template>
