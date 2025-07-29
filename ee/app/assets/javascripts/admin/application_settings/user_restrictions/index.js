import Vue from 'vue';
import { parseRailsFormFields } from '~/lib/utils/forms';
import PrivateProfileRestrictions from './components/private_profile_restrictions.vue';

export const initPrivateProfileRestrictions = () => {
  const el = document.getElementById('js-admin-settings-user-private-profile-restrictions');

  if (!el) return false;

  const { defaultToPrivateProfiles, allowPrivateProfiles } = parseRailsFormFields(el);

  return new Vue({
    el,
    name: 'PrivateProfileRestrictionsRoot',
    render(createElement) {
      return createElement(PrivateProfileRestrictions, {
        props: {
          defaultToPrivateProfiles,
          allowPrivateProfiles,
        },
      });
    },
  });
};
