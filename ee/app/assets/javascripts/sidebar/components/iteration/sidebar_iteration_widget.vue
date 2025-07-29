<script>
import {
  GlDropdownDivider,
  GlDropdownItem,
  GlDropdownSectionHeader,
  GlIcon,
  GlLink,
  GlTooltipDirective,
} from '@gitlab/ui';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import { getIterationPeriod, groupByIterationCadences } from 'ee/iterations/utils';
import { TYPE_ISSUE } from '~/issues/constants';
import { IssuableAttributeType } from '../../constants';
import SidebarDropdownWidget from '../sidebar_dropdown_widget.vue';

export default {
  issuableAttribute: IssuableAttributeType.Iteration,
  components: {
    GlDropdownDivider,
    GlDropdownItem,
    GlDropdownSectionHeader,
    GlIcon,
    GlLink,
    SidebarDropdownWidget,
    IterationTitle,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    attrWorkspacePath: {
      required: true,
      type: String,
    },
    iid: {
      required: true,
      type: String,
    },
    issuableType: {
      type: String,
      required: true,
      validator(value) {
        return value === TYPE_ISSUE;
      },
    },
    workspacePath: {
      required: true,
      type: String,
    },
    issueId: {
      required: false,
      type: String,
      default: '',
    },
  },
  methods: {
    getCadenceTitle(currentIteration) {
      return currentIteration?.iterationCadence?.title;
    },
    groupByIterationCadences,
    getIterationPeriod,
  },
};
</script>

<template>
  <sidebar-dropdown-widget
    :attr-workspace-path="attrWorkspacePath"
    :iid="iid"
    :issuable-attribute="$options.issuableAttribute"
    :issuable-type="issuableType"
    :workspace-path="workspacePath"
    :issue-id="issueId"
    @attribute-updated="$emit('iteration-updated', $event)"
  >
    <template #value="{ attributeUrl, currentAttribute }">
      <p class="gl-font-size-sm gl-line-height-21 gl-my-1 gl-text-subtle">
        {{ getCadenceTitle(currentAttribute) }}
      </p>
      <gl-link
        class="gl-leading-20 !gl-text-default"
        :href="attributeUrl"
        data-testid="iteration-link"
      >
        <div>
          <gl-icon name="iteration" class="gl-mr-1" />
          {{ getIterationPeriod(currentAttribute) }}
        </div>
        <iteration-title v-if="currentAttribute.title" :title="currentAttribute.title" />
      </gl-link>
    </template>
    <template #value-collapsed="{ currentAttribute }">
      <div
        v-if="currentAttribute"
        v-gl-tooltip.left.viewport
        :title="__('Iteration')"
        class="sidebar-collapsed-icon"
      >
        <gl-icon :aria-label="__('Iteration')" name="iteration" />
        <span class="collapse-truncated-title gl-px-3 gl-pt-2 gl-text-sm">
          {{ getIterationPeriod(currentAttribute) }}
        </span>
      </div>
    </template>
    <template #list="{ attributesList = [], isAttributeChecked, updateAttribute }">
      <template v-for="(cadence, index) in groupByIterationCadences(attributesList)">
        <gl-dropdown-divider v-if="index !== 0" :key="index" />
        <gl-dropdown-section-header :key="cadence.title" data-testid="cadence-title">
          {{ cadence.title }}
        </gl-dropdown-section-header>
        <gl-dropdown-item
          v-for="iteration in cadence.iterations"
          :key="iteration.id"
          is-check-item
          :is-checked="isAttributeChecked(iteration.id)"
          :data-testid="`${$options.issuableAttribute}-items`"
          @click="updateAttribute(iteration)"
        >
          {{ iteration.period }}
          <iteration-title v-if="iteration.title" :title="iteration.title" />
        </gl-dropdown-item>
      </template>
    </template>
  </sidebar-dropdown-widget>
</template>
