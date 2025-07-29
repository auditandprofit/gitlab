<script>
import { GlAlert } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';

export default {
  components: {
    GlAlert,
    MountingPortal,
  },
};
</script>

<template>
  <mounting-portal mount-to=".flash-container" name="amazon-q-disconnect-success-alert" append>
    <gl-alert
      :title="s__('AmazonQ|GitLab Duo with Amazon Q has been successfully disconnected')"
      variant="success"
      dismissible
      v-bind="$attrs"
      v-on="$listeners"
    >
      <p>
        {{
          s__('AmazonQ|To completely remove GitLab Duo with Amazon Q, update the following in AWS:')
        }}
      </p>
      <ul>
        <li>{{ s__('AmazonQ|Delete the IAM role.') }}</li>
        <li>{{ s__('AmazonQ|Delete the IAM identity provider created for AI gateway.') }}</li>
      </ul>
    </gl-alert>
  </mounting-portal>
</template>
