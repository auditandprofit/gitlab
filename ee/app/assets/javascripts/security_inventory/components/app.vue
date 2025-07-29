<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';

import Dashboard from './inventory_dashboard.vue';

export default {
  components: {
    PageHeading,
    Dashboard,
    GlExperimentBadge,
  },
  i18n: {
    title: s__('SecurityInventory|Security inventory'),
    description: s__(
      'SecurityInventory|View security coverage and vulnerabilities for all the projects in this group.',
    ),
  },
};
</script>

<template>
  <div>
    <page-heading data-testid="vulnerability-report-header">
      <template #heading>
        <div class="gl-flex gl-items-start">
          <span>{{ $options.i18n.title }}</span>
          <gl-experiment-badge class="gl-ml-3 gl-mt-3" type="beta" />
        </div>
      </template>
      <template #description>{{ $options.i18n.description }}</template></page-heading
    >
    <dashboard />
  </div>
</template>
