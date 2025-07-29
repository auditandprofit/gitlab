<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogNavTabs from './components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from './components/ai_catalog_nav_actions.vue';

export default {
  name: 'AiCatalogApp',
  components: {
    AiCatalogNavTabs,
    AiCatalogNavActions,
    PageHeading,
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|AI Catalog')">
      <template #actions>
        <ai-catalog-nav-actions />
      </template>
    </page-heading>
    <ai-catalog-nav-tabs />
    <router-view />
  </div>
</template>
