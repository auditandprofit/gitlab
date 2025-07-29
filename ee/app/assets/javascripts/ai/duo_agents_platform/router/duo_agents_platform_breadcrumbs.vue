<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AGENTS_PLATFORM_INDEX_ROUTE } from './constants';

export default {
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
  },
  computed: {
    crumbs() {
      // Get the first matched items. Iterate over each of them and make then a breadcrumb item
      // only if they have a meta field with text in
      const matchedRoutes = (this.$route?.matched || [])
        .map((route) => {
          return {
            text:
              !route.meta && this.$route.params.id
                ? String(this.$route.params.id)
                : route.meta?.text,
            to: { path: route.path },
          };
        })
        .filter((r) => r.text);

      return [...this.staticCrumbs, ...matchedRoutes];
    },
    staticCrumbs() {
      return [
        ...this.staticBreadcrumbs,
        {
          text: s__('DuoAgentsPlatform|Automate'),
          to: { name: AGENTS_PLATFORM_INDEX_ROUTE },
        },
      ];
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
