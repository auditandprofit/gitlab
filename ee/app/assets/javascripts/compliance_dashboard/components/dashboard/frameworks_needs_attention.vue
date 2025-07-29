<script>
import { GlButton, GlLink, GlTable } from '@gitlab/ui';
import { s__ } from '~/locale';
import { relativePathToAbsolute, getBaseURL } from '~/lib/utils/url_utility';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import FrameworkBadge from '../shared/framework_badge.vue';
import { ROUTE_EDIT_FRAMEWORK } from '../../constants';

export default {
  components: {
    GlButton,
    GlLink,
    GlTable,

    FrameworkBadge,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['groupSecurityPoliciesPath'],
  props: {
    frameworks: {
      type: Array,
      required: true,
    },
  },
  computed: {
    canAdminComplianceFramework() {
      return this.glAbilities.adminComplianceFramework;
    },
    tableFields() {
      return [
        {
          key: 'framework',
          label: s__('Compliance report|Framework name'),
        },
        {
          key: 'projectsCount',
          label: s__('Compliance report|Projects'),
          thClass: 'gl-w-10 gl-text-right',
          tdClass: 'gl-w-10 gl-text-right',
        },
        {
          key: 'requirementsCount',
          label: s__('Compliance report|Requirements'),
          thClass: 'md:gl-max-w-12 gl-text-right',
          tdClass: 'md:gl-max-w-12 gl-text-right',
        },
        {
          key: 'requirementsWithoutControls',
          label: s__('Compliance report|Requirements without controls'),
        },
        {
          key: 'policies',
          label: s__('Compliance report|Policies'),
        },
        this.canAdminComplianceFramework
          ? {
              key: 'actions',
              label: s__('Compliance report|Actions'),
              tdClass: 'md:gl-w-12',
            }
          : null,
      ].filter(Boolean);
    },
  },
  methods: {
    getIdFromGraphQLId,
    getPolicies(framework) {
      return [
        ...framework.scanExecutionPolicies.nodes,
        ...framework.vulnerabilityManagementPolicies.nodes,
        ...framework.scanResultPolicies.nodes,
        ...framework.pipelineExecutionPolicies.nodes,
      ].map((node) => ({
        name: node.name,
        webUrl: relativePathToAbsolute(
          `${this.groupSecurityPoliciesPath}/${node.name}/edit?type=${
            Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
              // eslint-disable-next-line no-underscore-dangle
              (o) => o.typeName === node.__typename,
            ).urlParameter
          }`,
          getBaseURL(),
        ),
      }));
    },
  },
  ROUTE_EDIT_FRAMEWORK,
};
</script>
<template>
  <div class="!gl-overflow-auto">
    <gl-table :fields="tableFields" :items="frameworks" no-local-sorting stacked="md">
      <template #cell(framework)="{ value }">
        <framework-badge :framework="value" popover-mode="hidden" />
      </template>
      <template #cell(projectsCount)="{ value }">
        <template v-if="value === 0">
          <span class="gl-font-bold gl-text-danger">{{ value }}</span>
        </template>
        <template v-else>
          {{ value }}
        </template>
      </template>
      <template #cell(requirementsCount)="{ value }">
        <template v-if="value === 0">
          <span class="gl-font-bold gl-text-danger">{{ value }}</span>
        </template>
        <template v-else>
          {{ value }}
        </template>
      </template>
      <template #cell(requirementsWithoutControls)="{ value }">
        <template v-if="value.length === 0">-</template>
        <template v-else>
          <ul class="gl-pl-3 gl-text-danger">
            <li v-for="item in value" :key="item.id">
              {{ item.name }}
            </li>
          </ul>
        </template>
      </template>
      <template #cell(policies)="{ item }">
        <template v-if="getPolicies(item.framework).length === 0">-</template>
        <template v-else>
          <ul class="gl-pl-3">
            <li v-for="policy in getPolicies(item.framework)" :key="policy.id">
              <gl-link :href="policy.webUrl">{{ policy.name }}</gl-link>
            </li>
          </ul>
        </template>
      </template>
      <template #cell(actions)="{ item }">
        <gl-button
          category="primary"
          variant="default"
          size="small"
          @click="
            $router.push({
              name: $options.ROUTE_EDIT_FRAMEWORK,
              params: { id: getIdFromGraphQLId(item.id) },
            })
          "
          >{{ s__('Compliance report|Edit framework') }}</gl-button
        >
      </template>
    </gl-table>
  </div>
</template>
