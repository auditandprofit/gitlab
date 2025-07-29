<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_FLOWS_ROUTE } from '../router/constants';

export default {
  components: {
    GlTab,
    GlTabs,
  },
  computed: {
    tabs() {
      return [
        {
          text: s__('AICatalog|Agents'),
          route: AI_CATALOG_AGENTS_ROUTE,
          active: this.$route.path.startsWith(AI_CATALOG_AGENTS_ROUTE),
        },
        {
          text: s__('AICatalog|Flows'),
          route: AI_CATALOG_FLOWS_ROUTE,
          active: this.$route.path.startsWith(AI_CATALOG_FLOWS_ROUTE),
        },
      ];
    },
  },
  methods: {
    navigateTo(route) {
      if (this.$route.path !== route) {
        this.$router.push({ name: route });
      }
    },
  },
};
</script>

<template>
  <div class="gl-mb-4 gl-flex lg:gl-items-center">
    <gl-tabs content-class="gl-py-0" class="gl-w-full">
      <gl-tab
        v-for="tab in tabs"
        :key="tab.text"
        :title="tab.text"
        :active="tab.active"
        @click="navigateTo(tab.route)"
      />
    </gl-tabs>
  </div>
</template>
