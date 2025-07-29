<script>
import { GlSprintf, GlExperimentBadge } from '@gitlab/ui';

export default {
  components: { GlSprintf, GlExperimentBadge },
  props: {
    sprintfMessage: { type: String, required: true },
    showExperimentBadge: { type: Boolean, default: false, required: false },
  },
  computed: {
    valueName() {
      // Get the name of the placeholder that's not %{labelStart} or %{labelEnd}.
      return this.sprintfMessage.match(/%{(?!(labelStart|labelEnd))(.+)}/)[2];
    },
  },
};
</script>

<template>
  <li :data-testid="valueName" class="!gl-ml-0 gl-mb-4 gl-list-none">
    <gl-sprintf :message="sprintfMessage">
      <template #label="{ content }">
        <gl-experiment-badge v-if="showExperimentBadge" class="gl-ml-0" />
        <strong data-testid="label">{{ content }}</strong>
      </template>
      <template #[valueName]>
        <span data-testid="value"><slot></slot></span>
      </template>
    </gl-sprintf>
  </li>
</template>
