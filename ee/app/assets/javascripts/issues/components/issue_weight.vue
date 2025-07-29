<script>
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

export default {
  name: 'IssueCardWeight',
  components: {
    WorkItemAttribute,
  },
  props: {
    weight: {
      type: Number,
      required: true,
    },
  },
};
</script>

<template>
  <work-item-attribute
    wrapper-component="button"
    anchor-id="board-card-weight"
    wrapper-component-class="board-card-info board-card-weight gl-mr-3 gl-inline-flex gl-cursor-help gl-items-center gl-align-bottom gl-text-sm gl-text-subtle !gl-cursor-help gl-bg-transparent gl-border-0 gl-p-0 focus-visible:gl-focus-inset"
    :title="`${weight}`"
    title-component-class="board-card-info-text"
    icon-name="weight"
    icon-class="board-card-info-icon gl-mr-2"
  >
    <template #tooltip-text>
      {{ __('Weight') }}<br /><span class="gl-text-tertiary">{{ weight }}</span>
    </template>
  </work-item-attribute>
</template>
