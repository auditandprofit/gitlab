import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenUpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/maven/upstream_details_app.vue';

initSimpleApp('#js-vue-maven-upstream-details', MavenUpstreamDetailsApp, {
  name: 'MavenUpstreamDetails',
});
