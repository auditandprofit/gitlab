<script>
export default {
  props: {
    parentItem: {
      type: Object,
      required: true,
    },
    children: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <!-- eslint-disable-next-line vue/no-undef-components -->
  <tree-root :parent-item="parentItem" :children="children" />
</template>
