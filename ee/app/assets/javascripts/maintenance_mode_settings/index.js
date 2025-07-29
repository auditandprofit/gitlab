import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import Translate from '~/vue_shared/translate';
import MaintenanceModeSettingsApp from './components/app.vue';
import { createStore } from './store';

Vue.use(Translate);

export const initMaintenanceModeSettings = () => {
  const el = document.getElementById('js-maintenance-mode-settings');

  if (!el) {
    return false;
  }

  const { maintenanceEnabled: maintenanceEnabledStr, bannerMessage } = el.dataset;
  const maintenanceEnabled = parseBoolean(maintenanceEnabledStr);

  return new Vue({
    el,
    store: createStore({ maintenanceEnabled, bannerMessage }),
    render(createElement) {
      return createElement(MaintenanceModeSettingsApp);
    },
  });
};
