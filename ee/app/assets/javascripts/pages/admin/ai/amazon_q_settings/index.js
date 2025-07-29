import Vue from 'vue';
import PortalVue from 'portal-vue';
import SettingsApp from 'ee/amazon_q_settings/components/app.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

Vue.use(PortalVue);

initSimpleApp('#js-amazon-q-settings', SettingsApp);
