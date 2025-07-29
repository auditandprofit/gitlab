<script>
import { GlTooltipDirective, GlLoadingIcon, GlButton, GlIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters, mapActions, mapState } from 'vuex';

import { __ } from '~/locale';

import { ChildType, treeItemChevronBtnKey } from '../constants';
import TreeItemBody from './tree_item_body.vue';

export default {
  ChildType,
  components: {
    GlIcon,
    TreeItemBody,
    GlLoadingIcon,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    parentItem: {
      type: Object,
      required: true,
    },
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapState(['children', 'childrenFlags']),
    ...mapGetters(['anyParentHasChildren']),
    itemReference() {
      return this.item.reference;
    },
    hasChildren() {
      return this.childrenFlags[this.itemReference].itemHasChildren;
    },
    chevronType() {
      return this.childrenFlags[this.itemReference].itemExpanded ? 'chevron-down' : 'chevron-right';
    },
    chevronTooltip() {
      return this.childrenFlags[this.itemReference].itemExpanded ? __('Collapse') : __('Expand');
    },
    childrenFetchInProgress() {
      return this.hasChildren && this.childrenFlags[this.itemReference].itemChildrenFetchInProgress;
    },
    itemExpanded() {
      return this.hasChildren && this.childrenFlags[this.itemReference].itemExpanded;
    },
    hasNoChildren() {
      return (
        this.anyParentHasChildren &&
        !this.hasChildren &&
        !this.childrenFlags[this.itemReference].itemChildrenFetchInProgress
      );
    },
    showEpicDropzone() {
      return !this.hasChildren && this.item.type === ChildType.Epic;
    },
  },
  methods: {
    ...mapActions(['toggleItem']),
    handleChevronClick() {
      this.toggleItem({
        parentItem: this.item,
      });
    },
  },
  treeItemChevronBtnKey,
};
</script>

<template>
  <li
    class="tree-item list-item gl-py-0"
    data-testid="related-issue-item"
    :class="{
      'has-children': hasChildren,
      'item-expanded': childrenFlags[itemReference].itemExpanded,
      'js-item-type-epic item-type-epic': item.type === $options.ChildType.Epic,
      'js-item-type-issue item-type-issue': item.type === $options.ChildType.Issue,
    }"
  >
    <div class="list-item-body gl-flex gl-items-center">
      <gl-button
        v-if="!childrenFetchInProgress && hasChildren"
        v-gl-tooltip.viewport.hover
        :title="chevronTooltip"
        :aria-label="chevronTooltip"
        :class="chevronType"
        variant="link"
        :data-button-type="$options.treeItemChevronBtnKey"
        class="gl-mb-2 gl-mr-2 gl-self-start !gl-py-3 !gl-leading-[0px] !gl-text-gray-900 hover:gl-border-default hover:!gl-bg-gray-100"
        @click="handleChevronClick"
      >
        <gl-icon :name="chevronType" />
      </gl-button>
      <gl-loading-icon
        v-if="childrenFetchInProgress"
        class="gl-mb-2 gl-mr-2 gl-self-start gl-py-3"
        size="sm"
      />
      <tree-item-body
        class="tree-item-row gl-mb-3"
        :parent-item="parentItem"
        :item="item"
        :class="{
          'tree-item-noexpand': hasNoChildren,
        }"
      />
    </div>
    <!-- eslint-disable-next-line vue/no-undef-components -->
    <tree-root
      v-if="itemExpanded || showEpicDropzone"
      :parent-item="item"
      :children="
        children[itemReference] ||
        [] /* eslint-disable-line @gitlab/vue-no-new-non-primitive-in-template */
      "
      class="sub-tree-root"
    />
  </li>
</template>
