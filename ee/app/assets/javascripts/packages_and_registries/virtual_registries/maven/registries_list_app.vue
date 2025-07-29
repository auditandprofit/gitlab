<script>
import { GlAlert, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getMavenVirtualRegistriesList } from 'ee/api/virtual_registries_api';
import MavenRegistryItem from 'ee/packages_and_registries/virtual_registries/components/maven_registry_item.vue';

export default {
  name: 'MavenRegistriesListApp',
  components: {
    GlAlert,
    GlEmptyState,
    GlSkeletonLoader,
    MavenRegistryItem,
  },
  inject: ['fullPath'],
  data() {
    return {
      alertMessage: '',
      isLoading: false,
      registries: [],
    };
  },
  computed: {
    hasRegistries() {
      return this.registries.length > 0;
    },
  },
  created() {
    this.fetchRegistries();
  },
  methods: {
    async fetchRegistries() {
      this.isLoading = true;
      this.alertMessage = '';
      try {
        const response = await getMavenVirtualRegistriesList({
          id: this.fullPath,
        });
        this.registries = response.data;
      } catch (error) {
        this.alertMessage =
          error.message || s__('VirtualRegistry|Failed to fetch list of maven virtual registries.');
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <gl-alert v-if="alertMessage" variant="danger">
    {{ alertMessage }}
  </gl-alert>
  <gl-skeleton-loader v-else-if="isLoading" :lines="2" :width="500" />
  <ul v-else-if="hasRegistries" class="gl-p-0">
    <maven-registry-item v-for="registry in registries" :key="registry.id" :registry="registry" />
  </ul>
  <gl-empty-state
    v-else
    :title="s__('VirtualRegistry|There are no maven virtual registries yet')"
  />
</template>
