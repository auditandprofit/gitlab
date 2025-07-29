<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  computed: {
    standards() {
      return [
        {
          text: __('GitLab'),
          value: 'GITLAB',
        },
      ];
    },
  },
  methods: {
    findActiveStandard(inputValue) {
      const activeStandard = this.standards.find((standard) => standard.value === this.value.data);

      return activeStandard?.text || inputValue;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="$listeners">
    <template #view="{ inputValue }">
      {{ findActiveStandard(inputValue) }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="(standard, index) in standards"
        :key="index"
        :value="standard.value"
      >
        {{ standard.text }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
