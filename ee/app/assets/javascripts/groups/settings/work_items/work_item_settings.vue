<script>
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import CustomFieldsList from './custom_fields_list.vue';
import CustomStatusSettings from './custom_status_settings.vue';

export default {
  components: {
    CustomFieldsList,
    CustomStatusSettings,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    workItemStatusFeatureFlagEnabled() {
      return this.glFeatures.workItemStatusFeatureFlag;
    },
  },
};
</script>

<template>
  <div>
    <custom-status-settings v-if="workItemStatusFeatureFlagEnabled" :full-path="fullPath" />
    <custom-fields-list :full-path="fullPath" />
  </div>
</template>
