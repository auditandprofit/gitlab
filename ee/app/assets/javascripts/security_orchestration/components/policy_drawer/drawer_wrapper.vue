<script>
import {
  GlButton,
  GlDrawer,
  GlLink,
  GlPopover,
  GlSprintf,
  GlTabs,
  GlTab,
  GlTruncate,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { policyToYaml } from 'ee/security_orchestration/components/policy_editor/utils';
import { removeUnnecessaryDashes } from '../../utils';
import { POLICIES_LIST_CONTAINER_CLASS, POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';
import { extractPolicyContent, isPolicyInherited, policyHasNamespace } from '../utils';
import PipelineExecutionDrawer from './pipeline_execution/details_drawer.vue';
import ScanExecutionDrawer from './scan_execution/details_drawer.vue';
import ScanResultDrawer from './scan_result/details_drawer.vue';
import VulnerabilityManagementDrawer from './vulnerability_management/details_drawer.vue';

const policyComponent = {
  [POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value]: ScanExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.approval.value]: ScanResultDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.value]: PipelineExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.value]: PipelineExecutionDrawer,
  [POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.value]: VulnerabilityManagementDrawer,
};

export default {
  components: {
    GlButton,
    GlDrawer,
    GlLink,
    GlPopover,
    GlSprintf,
    GlTab,
    GlTabs,
    GlTruncate,
    YamlEditor: () => import(/* webpackChunkName: 'policy_yaml_editor' */ '../yaml_editor.vue'),
    PipelineExecutionDrawer,
    ScanExecutionDrawer,
    ScanResultDrawer,
  },
  props: {
    containerClass: {
      type: String,
      required: false,
      default: POLICIES_LIST_CONTAINER_CLASS,
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    policyType: {
      type: String,
      required: false,
      default: '',
    },
    disableScanPolicyUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    isPolicyInherited() {
      return isPolicyInherited(this.policy.source);
    },
    policyHasNamespace() {
      return policyHasNamespace(this.policy.source);
    },
    policyComponent() {
      return policyComponent[this.policyType] || null;
    },
    policyYaml() {
      const type =
        Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(({ value }) => value === this.policyType)
          ?.urlParameter || '';

      return policyToYaml(
        extractPolicyContent({
          manifest: removeUnnecessaryDashes(this.policy.yaml),
          type,
        }),
        type,
      );
    },
    sourcePolicyListUrl() {
      return getSecurityPolicyListUrl({ namespacePath: this.policy.source.namespace.fullPath });
    },
  },
  methods: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight(this.containerClass);
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    editButtonPopoverMessage: s__(
      'SecurityOrchestration|This policy is inherited from %{linkStart}namespace%{linkEnd} and must be edited there',
    ),
    tabDetails: s__('SecurityOrchestration|Details'),
    tabYaml: s__('SecurityOrchestration|YAML'),
  },
};
</script>

<template>
  <gl-drawer
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="getDrawerHeaderHeight()"
    v-bind="$attrs"
    v-on="$listeners"
  >
    <template v-if="policy" #title>
      <gl-truncate
        class="gl-max-w-34 gl-text-size-h2 gl-font-bold gl-leading-24"
        :text="policy.name"
        with-tooltip
      />
    </template>
    <template v-if="policy" #header>
      <span v-if="!disableScanPolicyUpdate" ref="editButton" class="gl-inline-block">
        <gl-button
          class="gl-mt-5"
          data-testid="edit-button"
          category="primary"
          variant="confirm"
          :href="policy.editPath"
          :disabled="isPolicyInherited"
          >{{ s__('SecurityOrchestration|Edit policy') }}</gl-button
        >
      </span>
      <gl-popover
        v-if="isPolicyInherited && policyHasNamespace"
        triggers="hover"
        :target="() => $refs.editButton"
        data-testid="edit-button-popover"
        placement="right"
      >
        <gl-sprintf :message="$options.i18n.editButtonPopoverMessage">
          <template #link>
            <gl-link :href="sourcePolicyListUrl">
              {{ policy.source.namespace.name }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-popover>
    </template>
    <gl-tabs v-if="policy" class="!gl-p-0" justified content-class="gl-py-0" lazy>
      <gl-tab :title="$options.i18n.tabDetails" class="gl-ml-6 gl-mr-3 gl-mt-5">
        <component :is="policyComponent" v-if="policyComponent" :policy="policy" />
        <div v-else>
          <h5>{{ s__('SecurityOrchestration|Policy definition') }}</h5>
          <p>
            {{
              s__("SecurityOrchestration|Define this policy's location, conditions and actions.")
            }}
          </p>
          <yaml-editor :value="policyYaml" data-testid="policy-yaml-editor-default-component" />
        </div>
      </gl-tab>
      <gl-tab v-if="policyComponent" :title="$options.i18n.tabYaml">
        <yaml-editor
          class="gl-h-screen"
          :value="policyYaml"
          data-testid="policy-yaml-editor-tab-content"
        />
      </gl-tab>
    </gl-tabs>
  </gl-drawer>
</template>
