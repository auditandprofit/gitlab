import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import EditMavenUpstreamApp from 'ee/packages_and_registries/virtual_registries/maven/edit_upstream_app.vue';

initSimpleApp('#js-vue-virtual-registry-edit-maven-upstream', EditMavenUpstreamApp, {
  name: 'VirtualRegistryEditMavenUpstream',
});
