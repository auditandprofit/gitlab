import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/maven/registry_details_app.vue';

initSimpleApp('#js-vue-maven-registry-details', MavenRegistryDetailsApp, {
  withApolloProvider: true,
  name: 'MavenRegistryDetails',
});
