import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import HandRaiseLeadButton from './components/hand_raise_lead_button.vue';

export default function initHandRaiseLeadButton() {
  const triggers = document.querySelectorAll('.js-hand-raise-lead-trigger');

  if (!triggers) {
    return false;
  }

  return triggers.forEach((el) => {
    const { buttonAttributes, ctaTracking } = el.dataset;

    return new Vue({
      el,
      name: 'HandRaiseLeadButtonRoot',
      render: (createElement) =>
        createElement(HandRaiseLeadButton, {
          props: {
            ...el.dataset,
            ctaTracking: convertObjectPropsToCamelCase(JSON.parse(ctaTracking)),
            buttonAttributes: convertObjectPropsToCamelCase(JSON.parse(buttonAttributes)),
          },
        }),
    });
  });
}
