<script>
import { s__ } from '~/locale';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';

export default {
  name: 'MergeChecksSecurityPolicyViolations',
  components: {
    MergeChecksMessage,
    ActionButtons,
  },
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: Object,
      required: true,
    },
  },
  computed: {
    tertiaryActionsButtons() {
      return [
        this.mr.securityPoliciesPath && {
          href: this.mr.securityPoliciesPath,
          text: s__('MergeChecks|View policies'),
        },
      ].filter((x) => x);
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <template v-if="check.status !== 'INACTIVE'">
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />
    </template>
  </merge-checks-message>
</template>
