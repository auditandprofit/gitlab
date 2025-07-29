<script>
import { n__ } from '~/locale';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';

export default {
  name: 'MavenUpstreamDetailsHeader',
  components: {
    TitleArea,
    MetadataItem,
  },
  props: {
    upstream: {
      type: Object,
      required: true,
    },
  },
  computed: {
    artifactsCountText() {
      return n__('%d Artifact', '%d Artifacts', this.upstream.cacheEntriesCount || 0);
    },
  },
};
</script>

<template>
  <title-area :title="upstream.name">
    <template #metadata-registry-type>
      <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
    </template>
    <template #metadata-count>
      <metadata-item icon="doc-text" :text="artifactsCountText" />
    </template>
    <template #metadata-url>
      <metadata-item icon="earth" :text="upstream.url" size="xl" />
    </template>
    <p v-if="upstream.description" data-testid="description">{{ upstream.description }}</p>
  </title-area>
</template>
