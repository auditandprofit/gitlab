<script>
import { uniqueId } from 'lodash';
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlModal,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  data() {
    return {
      modalId: uniqueId('amazon-q-disconnect-warning-modal-'),
    };
  },
  I18N_TITLE: s__(
    'AmazonQ|Are you sure? Removing the ARN will disconnect Amazon Q from GitLab and all related features will stop working.',
  ),
  ACTION_PRIMARY: {
    text: s__("AmazonQ|Remove IAM role's ARN"),
    attributes: {
      variant: 'danger',
    },
  },
  ACTION_CANCEL: {
    text: s__('AmazonQ|Cancel'),
  },
};
</script>
<template>
  <gl-modal
    :modal-id="modalId"
    :title="$options.I18N_TITLE"
    :action-primary="$options.ACTION_PRIMARY"
    :action-cancel="$options.ACTION_CANCEL"
    v-bind="$attrs"
    v-on="$listeners"
    @primary="$emit('submit')"
  >
    <p>
      {{
        s__(
          "AmazonQ|If this is what you want, remove the IAM role's ARN. To completely remove GitLab Duo with Amazon Q, update the following in AWS:",
        )
      }}
    </p>
    <ol>
      <li>{{ s__('AmazonQ|Delete the IAM role.') }}</li>
      <li>{{ s__('AmazonQ|Delete the IAM identity provider created for AI gateway.') }}</li>
    </ol>
  </gl-modal>
</template>
