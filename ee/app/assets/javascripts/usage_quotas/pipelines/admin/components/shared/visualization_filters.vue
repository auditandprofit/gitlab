<script>
import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';

export default {
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
  },
  props: {
    runners: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      selectedRunner: null,
    };
  },
  created() {
    this.selectedRunner = this.runners[0].value;
  },
  methods: {
    onSelectedRunner(runner) {
      this.$emit('runnerSelected', runner);
    },
  },
};
</script>
<template>
  <div class="gl-my-4 gl-flex">
    <slot></slot>
    <gl-form-group :label="__('Runner')">
      <gl-collapsible-listbox
        v-model="selectedRunner"
        :items="runners"
        block
        data-testid="runner-filter"
        @select="onSelectedRunner"
      />
    </gl-form-group>
  </div>
</template>
