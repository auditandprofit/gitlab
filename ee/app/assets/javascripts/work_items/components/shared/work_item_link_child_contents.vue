<script>
import { GlTooltipDirective } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import WorkItemLinkChildContents from '~/work_items/components/shared/work_item_link_child_contents.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';

export default {
  name: 'WorkItemLinkChildContentsEE',
  components: {
    WorkItemLinkChildContents,
    WorkItemStatusBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    childItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    workItemFullPath: {
      type: String,
      required: true,
    },
    showLabels: {
      type: Boolean,
      required: false,
      default: true,
    },
    showWeight: {
      type: Boolean,
      required: false,
      default: true,
    },
    contextualViewEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    metadataWidgets() {
      return this.childItem.widgets?.reduce((metadataWidgets, widget) => {
        if (widget.type) {
          // eslint-disable-next-line no-param-reassign
          metadataWidgets[widget.type] = widget;
        }
        return metadataWidgets;
      }, {});
    },
    showCustomStatus() {
      return this.glFeatures.workItemStatusFeatureFlag && this.customStatus;
    },
    customStatus() {
      return this.metadataWidgets[WIDGET_TYPE_STATUS]?.status;
    },
  },
};
</script>

<template>
  <work-item-link-child-contents
    :child-item="childItem"
    :can-update="canUpdate"
    :show-labels="showLabels"
    :work-item-full-path="workItemFullPath"
    :show-weight="showWeight"
    :contextual-view-enabled="contextualViewEnabled"
    @click="$emit('click', $event)"
    @removeChild="$emit('removeChild', childItem)"
  >
    <template #child-contents>
      <div class="gl-max-w-20">
        <work-item-status-badge v-if="showCustomStatus" :item="customStatus" />
      </div>
    </template>
  </work-item-link-child-contents>
</template>
