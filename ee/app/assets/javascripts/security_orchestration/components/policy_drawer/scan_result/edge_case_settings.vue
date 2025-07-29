<script>
import { s__ } from '~/locale';
import {
  UNBLOCK_RULES_KEY,
  UNBLOCK_RULES_TEXT,
} from '../../policy_editor/scan_result/advanced_settings/constants';

export default {
  name: 'EdgeCaseSettings',
  i18n: {
    title: s__('SecurityOrchestration|Edge case settings'),
    [UNBLOCK_RULES_KEY]: UNBLOCK_RULES_TEXT,
  },
  props: {
    settings: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    settingsList() {
      return Object.entries(this.settings).map(([key]) => this.$options.i18n[key] || key);
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <h5>{{ $options.i18n.title }}</h5>
    <p v-for="key in settingsList" :key="key" class="gl-mb-2">
      {{ key }}
    </p>
  </div>
</template>
