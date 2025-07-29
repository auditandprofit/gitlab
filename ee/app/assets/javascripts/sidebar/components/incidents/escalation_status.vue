<script>
import EscalationStatus from '~/sidebar/components/incidents/escalation_status.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { i18nStatusHeaderText, STATUS_SUBTEXTS } from '../../constants';

export default {
  i18n: i18nStatusHeaderText,

  components: {
    EscalationStatus,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    // eslint-disable-next-line @gitlab/vue-require-required-key
    value: EscalationStatus.props.value,
  },
  computed: {
    headerText() {
      return this.escalationPoliciesEnabled ? this.$options.i18n : '';
    },
    statusSubtexts() {
      return this.escalationPoliciesEnabled ? STATUS_SUBTEXTS : {};
    },

    escalationPoliciesEnabled() {
      return this.glFeatures.escalationPolicies;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API
    show() {
      this.$refs.escalationStatus.show();
    },
    // eslint-disable-next-line vue/no-unused-properties -- hide() is part of the component's public API
    hide() {
      this.$refs.escalationStatus.hide();
    },
  },
};
</script>

<template>
  <escalation-status
    ref="escalationStatus"
    :header-text="headerText"
    :status-subtexts="statusSubtexts"
    :value="value"
    v-bind="$attrs"
    v-on="$listeners"
  />
</template>
