<script>
import { GlFormInput } from '@gitlab/ui';
import { debounce } from 'lodash';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { n__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { RULE_TYPE_ANY_APPROVER } from '../../constants';

const ANY_RULE_NAME = 'All Members';

export default {
  components: {
    GlFormInput,
  },
  i18n: {
    inputLabel(approvalsCount) {
      return n__('Approval required', 'Approvals required', approvalsCount);
    },
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    isBranchRulesEdit: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  computed: {
    ...mapState(['settings']),
    uniqueInputId() {
      return `approvals-number-field-${this.rule.id}`;
    },
    minInputValue() {
      return this.rule.minApprovalsRequired || 0;
    },
    isEnabled() {
      return this.isBranchRulesEdit
        ? this.glFeatures.editBranchRules && this.settings.canEdit
        : this.settings.canEdit;
    },
  },
  created() {
    this.onInputChangeDebounced = debounce((event) => {
      this.onInputChange(event);
    }, 1000);
  },
  methods: {
    ...mapActions(['putRule', 'postRule']),
    onInputChange(value) {
      const approvalsRequired = parseInt(value, 10);

      if (this.rule.id) {
        this.putRule({ id: this.rule.id, approvalsRequired });
      } else {
        this.postRule({
          name: ANY_RULE_NAME,
          ruleType: RULE_TYPE_ANY_APPROVER,
          approvalsRequired,
        });
      }
    },
  },
};
</script>

<template>
  <div>
    <label :for="uniqueInputId" class="gl-sr-only">
      {{ $options.i18n.inputLabel(rule.approvalsRequired) }}
    </label>
    <gl-form-input
      :id="uniqueInputId"
      :value="rule.approvalsRequired"
      :disabled="!isEnabled"
      class="-gl-my-3 gl-ml-auto gl-w-10 md:gl-mr-auto"
      type="number"
      name="approvals-number-field"
      :min="minInputValue"
      data-testid="approvals-number-field"
      @input="onInputChangeDebounced"
    />
  </div>
</template>
