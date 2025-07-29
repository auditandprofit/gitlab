<script>
import { EXCEPTIONS_FULL_OPTIONS_MAP } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import { onlyValidKeys } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
import PolicyExceptionsSelectedItem from './policy_exceptions_selected_item.vue';

export default {
  name: 'PolicyExceptionsSelectedList',
  components: {
    PolicyExceptionsSelectedItem,
  },
  props: {
    selectedExceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    hasExceptions() {
      return this.formattedSelectedExceptions.length > 0;
    },
    formattedSelectedExceptions() {
      return onlyValidKeys(Object.keys(this.selectedExceptions)).map((key) => {
        const count = Array.isArray(this.selectedExceptions[key])
          ? this.selectedExceptions[key].length
          : 0;

        return {
          title: EXCEPTIONS_FULL_OPTIONS_MAP[key]?.header,
          count,
          key,
        };
      });
    },
  },
  methods: {
    editItem(key) {
      this.$emit('edit-item', key);
    },
    removeItem(key) {
      this.$emit('remove', key);
    },
  },
};
</script>

<template>
  <div :class="{ 'gl-mb-2': hasExceptions }">
    <policy-exceptions-selected-item
      v-for="exception in formattedSelectedExceptions"
      :key="exception.title"
      :count="exception.count"
      :exception-key="exception.key"
      :title="exception.title"
      @select-item="editItem"
      @remove="removeItem"
    />
  </div>
</template>
