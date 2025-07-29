<script>
import { GlButton } from '@gitlab/ui';
import UserFeedback from 'ee/ai/components/user_feedback.vue';

export default {
  components: {
    GlButton,
    UserFeedback,
  },
};
</script>

<template>
  <div>
    <user-feedback
      event-name="duo_code_review"
      :feedback-link-text="__('Rate the review')"
      class="gl-inline-block !gl-pt-0"
    />
    <span class="gl-mx-2">&middot;</span>
    <gl-button variant="link" href="https://gitlab.com/gitlab-org/gitlab/-/issues/517386">
      {{ __('Leave feedback') }}
    </gl-button>
  </div>
</template>
