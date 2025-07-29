<script>
import { InternalEvents } from '~/tracking';

export default {
  mixins: [InternalEvents.mixin()],
  mounted() {
    this.trackEvent('view_project_security_attributes');
  },
};
</script>
<template>
  <p class="gl-my-5">
    {{
      s__(
        'SecurityAttributes|Security attributes help classify and organize your projects. Attributes are managed at the group level. You can add or remove attributes to this project as needed.',
      )
    }}
  </p>
</template>
