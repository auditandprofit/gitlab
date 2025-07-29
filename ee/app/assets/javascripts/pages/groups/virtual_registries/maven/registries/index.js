import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import MavenRegistriesListApp from 'ee/packages_and_registries/virtual_registries/maven/registries_list_app.vue';

initSimpleApp('#js-vue-maven-virtual-registries-list', MavenRegistriesListApp, {
  name: 'MavenVirtualRegistryList',
});
