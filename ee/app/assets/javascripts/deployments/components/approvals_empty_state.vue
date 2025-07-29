<script>
import { GlIcon, GlButton } from '@gitlab/ui';
import emptyStateIllustration from '@gitlab/svgs/dist/illustrations/status/status-settings-sm.svg';
import ApprovalsEmptyState from '~/deployments/components/approvals_empty_state.vue';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  components: {
    ApprovalsEmptyState,
    GlIcon,
    GlButton,
  },
  inject: ['protectedEnvironmentsAvailable', 'protectedEnvironmentsSettingsPath'],
  props: {
    approvalSummary: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    showEmptyState() {
      return !this.approvalSummary.rules?.length;
    },
  },
  i18n: {
    bannerTitle: s__('Deployment|Set up deployment approvals to get more our of your deployments'),
    buttonText: s__('Deployment|Set up Deployment Approvals'),
    tableHeader: s__('Deployment|Set up deployment approvals to get started'),
    learnMoreText: __('Learn more'),
  },
  learnMoreLink: helpPagePath('ci/environments/deployment_approvals'),
  emptyStateIllustration,
};
</script>
<template>
  <approvals-empty-state
    v-if="showEmptyState && protectedEnvironmentsAvailable"
    :banner-title="$options.i18n.bannerTitle"
    :button-text="$options.i18n.buttonText"
    :button-link="protectedEnvironmentsSettingsPath"
    :illustration="$options.emptyStateIllustration"
  >
    <template #table-header>
      <gl-icon name="approval" class="gl-mr-2" /> <span>{{ $options.i18n.tableHeader }}</span>
    </template>
    <template #banner-actions>
      <gl-button category="secondary" :href="$options.learnMoreLink" class="gl-ml-2">
        {{ $options.i18n.learnMoreText }}
      </gl-button>
    </template>
  </approvals-empty-state>
  <approvals-empty-state v-else-if="showEmptyState" />
</template>
