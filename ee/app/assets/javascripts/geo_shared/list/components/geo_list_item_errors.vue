<script>
import { GlCollapse, GlButton } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'GeoListItemErrors',
  i18n: {
    showErrors: __('Show errors'),
    hideErrors: __('Hide errors'),
  },
  components: {
    GlCollapse,
    GlButton,
  },
  props: {
    errorsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isVisible: false,
    };
  },
  computed: {
    toggleButtonText() {
      return this.isVisible ? this.$options.i18n.hideErrors : this.$options.i18n.showErrors;
    },
  },
  methods: {
    toggleErrorVisibility() {
      this.isVisible = !this.isVisible;
    },
  },
};
</script>

<template>
  <section class="gl-mt-3">
    <gl-button variant="link" size="small" class="gl-p-0" @click="toggleErrorVisibility">
      {{ toggleButtonText }}
    </gl-button>
    <gl-collapse :visible="isVisible">
      <div class="gl-border gl-mt-2 gl-rounded-base gl-border-red-200 gl-bg-red-50 gl-p-3">
        <div
          v-for="(error, index) in errorsArray"
          :key="index"
          class="gl-mb-2 last:gl-mb-0"
          data-testid="geo-list-error-item"
        >
          <p class="gl-mb-0 gl-text-sm">
            <span class="gl-font-bold gl-text-red-700">{{ error.label }}:</span>
            <span class="gl-ml-1 gl-text-red-700">{{ error.message }}</span>
          </p>
        </div>
      </div>
    </gl-collapse>
  </section>
</template>
