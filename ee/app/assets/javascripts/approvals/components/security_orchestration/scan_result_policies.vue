<script>
import { GlLink, GlButton, GlFormGroup } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import Container from '../rules/rules.vue';
import ScanResultPolicy from './scan_result_policy.vue';
import PolicyDetails from './policy_details.vue';

export default {
  i18n: {
    securityApprovals: s__('SecurityOrchestration|Security Approvals'),
    description: s__(
      'SecurityOrchestration|Create more robust vulnerability rules and apply them to all your projects.',
    ),
    learnMore: __('Learn more'),
    noPolicies: s__("SecurityOrchestration|You don't have any security policies yet"),
    createPolicy: s__('SecurityOrchestration|Create security policy'),
  },
  components: {
    Container,
    CrudComponent,
    GlLink,
    GlButton,
    ScanResultPolicy,
    PolicyDetails,
    GlFormGroup,
  },
  inject: ['fullPath', 'newPolicyPath'],
  computed: {
    ...mapState('securityOrchestrationModule', ['scanResultPolicies']),
    policies() {
      return this.scanResultPolicies;
    },
    hasPolicies() {
      return this.policies.length > 0;
    },
  },
  mounted() {
    this.fetchScanResultPolicies({ fullPath: this.fullPath });
  },
  methods: {
    ...mapActions('securityOrchestrationModule', ['fetchScanResultPolicies']),
    selectionChanged(index) {
      this.scanResultPolicies[index].isSelected = !this.scanResultPolicies[index].isSelected;
    },
  },
  scanResultPolicyHelpPagePath: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
  ),
};
</script>

<template>
  <gl-form-group>
    <crud-component :title="$options.i18n.securityApprovals" icon="shield" :count="policies.length">
      <template #description>
        {{ $options.i18n.description }}
        <gl-link :href="$options.scanResultPolicyHelpPagePath" target="_blank" class="gl-text-sm"
          >{{ $options.i18n.learnMore }}.</gl-link
        >
      </template>
      <template #actions>
        <gl-button category="secondary" size="small" :href="newPolicyPath">
          {{ $options.i18n.createPolicy }}
        </gl-button>
      </template>

      <container :rules="policies">
        <template #thead="{ name, approvalsRequired, branches }">
          <tr class="!gl-table-row">
            <th class="!gl-w-1/2">{{ name }}</th>
            <th>{{ branches }}</th>
            <th>{{ approvalsRequired }}</th>
            <th></th>
          </tr>
        </template>
        <template #tbody>
          <tr v-if="!hasPolicies">
            <td colspan="4" class="gl-p-5 gl-text-center gl-text-subtle">
              {{ $options.i18n.noPolicies }}.
            </td>
          </tr>
          <template v-for="(policy, index) in policies" v-else>
            <scan-result-policy
              :key="`${policy.name}-policy`"
              :policy="policy"
              @toggle="selectionChanged(index)"
            />
            <policy-details :key="`${policy.name}-details`" :policy="policy" />
          </template>
        </template>
      </container>
    </crud-component>
  </gl-form-group>
</template>
