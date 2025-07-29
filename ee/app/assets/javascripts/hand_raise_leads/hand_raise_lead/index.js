import * as Sentry from '~/sentry/sentry_browser_wrapper';

export function initHandRaiseLead() {
  const modalEl = document.querySelector('.js-hand-raise-lead-modal');

  if (modalEl) {
    import(/* webpackChunkName: 'initHandRaiseLeadModal' */ './init_hand_raise_lead_modal')
      .then(({ default: initHandRaiseLeadModal }) => {
        initHandRaiseLeadModal();
      })
      .catch((error) => Sentry.captureException(error));
  }

  const handRaiseLeadButton = document.querySelector('.js-hand-raise-lead-trigger');
  if (!handRaiseLeadButton) return;

  import(/* webpackChunkName: 'initHandRaiseLeadButton' */ './init_hand_raise_lead_button')
    .then(({ default: initHandRaiseLeadButton }) => {
      initHandRaiseLeadButton();
    })
    .catch((error) => Sentry.captureException(error));
}
