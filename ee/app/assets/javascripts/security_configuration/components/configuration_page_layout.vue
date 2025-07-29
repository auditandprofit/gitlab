<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  components: {
    PageHeading,
  },
};
</script>

<template>
  <article>
    <slot name="alert"></slot>

    <page-heading>
      <template #heading>
        <slot name="heading"></slot>
      </template>

      <template #description>
        <slot name="description"></slot>
      </template>

      <template #actions>
        <slot name="actions"></slot>
      </template>
    </page-heading>

    <slot></slot>
  </article>
</template>
