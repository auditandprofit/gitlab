<script>
import { convertToGraphQLId } from '~/graphql_shared/utils';
import MavenRegistryDetails from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import getMavenVirtualRegistryUpstreams from '../graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import createUpstreamRegistryMutation from '../graphql/mutations/create_upstream_registry.mutation.graphql';

import { captureException } from '../sentry_utils';

const TYPENAME_VIRTUAL_REGISTRY = 'VirtualRegistries::Packages::Maven::Registry';

export default {
  name: 'RegistryDetailsRoot',
  components: {
    MavenRegistryDetails,
  },
  inject: {
    registry: {
      default: {},
    },
    registryEditPath: {
      default: '',
    },
    groupPath: {
      default: '',
    },
  },
  data() {
    return {
      group: {},
      loading: true,
      mavenVirtualRegistryID: convertToGraphQLId(TYPENAME_VIRTUAL_REGISTRY, this.registry.id),
    };
  },
  apollo: {
    group: {
      query: getMavenVirtualRegistryUpstreams,
      variables() {
        return {
          groupPath: this.groupPath,
          mavenVirtualRegistryID: this.mavenVirtualRegistryID,
        };
      },
      error(error) {
        this.handleError(error);
      },
    },
  },
  computed: {
    upstreams() {
      if (Object.keys(this.group).length === 0) {
        return {};
      }

      const { mavenVirtualRegistries } = this.group;
      const { upstreams } = mavenVirtualRegistries.nodes[0];

      return {
        count: upstreams.length,
        nodes: upstreams,
      };
    },
  },
  methods: {
    async upstreamAction(name, mutationData) {
      this.loading = true;

      try {
        const {
          data: {
            [name]: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: createUpstreamRegistryMutation,
          variables: mutationData,
        });

        if (errors.length > 0) {
          this.handleError(errors);
          // TODO: Add Toast
        } else {
          this.$apollo.queries.group.refetch();
        }
      } catch (error) {
        this.handleError(error);
      } finally {
        this.loading = false;
      }
    },
    createUpstream(event) {
      this.upstreamAction(this.$options.upstreamRegistryCreate, {
        id: this.mavenVirtualRegistryID,
        ...event,
      });
    },
    handleError(error) {
      captureException({ error, component: this.$options.name });
    },
  },
  upstreamRegistryCreate: 'mavenUpstreamCreate',
};
</script>
<template>
  <maven-registry-details
    :registry="registry"
    :upstreams="upstreams"
    @createUpstream="createUpstream"
  />
</template>
