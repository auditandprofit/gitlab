<script>
import { GlLabel } from '@gitlab/ui';
import { s__ } from '~/locale';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

const VALIDITY_CHECK_TYPE = {
  active: { color: '#c91c00', title: s__('Vulnerability|Active secret') },
  inactive: { color: '#428fdc', title: s__('Vulnerability|Inactive secret') },
  unknown: { color: '#ececef', title: s__('Vulnerability|Possibly active secret') },
};

export default {
  name: 'TokenValidityBadge',
  components: {
    GlLabel,
    HelpPopover,
  },
  props: {
    status: {
      type: String,
      required: false,
      default: 'unknown',
    },
  },
  i18n: {
    whatIsValidityCheck: {
      content: s__(
        'Vulnerability|GitLab checks the validity of the secret with the third party vendor on each pipeline run. If the secret is still active it could be exploited and needs to be revoked and rotated.',
      ),
      title: s__('Vulnerability|What is a validity check?'),
    },
  },
  computed: {
    validityCheckLabel() {
      switch (this.status) {
        case 'active':
          return VALIDITY_CHECK_TYPE.active;
        case 'inactive':
          return VALIDITY_CHECK_TYPE.inactive;
        default:
          return VALIDITY_CHECK_TYPE.unknown;
      }
    },
  },
};
</script>

<template>
  <div class="gl-inline-block">
    <gl-label
      :background-color="validityCheckLabel.color"
      :title="validityCheckLabel.title"
      data-testid="validityCheckLabel"
    />
    <help-popover class="gl-ml-2" :options="$options.i18n.whatIsValidityCheck" />
  </div>
</template>
