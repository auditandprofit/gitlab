import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { __ } from '~/locale';

const dismissTargetedMessage = (e) => {
  e.preventDefault();

  const targetedMessage = e.currentTarget.closest('.js-targeted-message');
  const ds = targetedMessage.dataset;

  if (!ds.targetedMessageId) return;

  targetedMessage.remove();

  axios
    .post(ds.dismissEndpoint, {
      targeted_message_id: ds.targetedMessageId,
      namespace_id: ds.namespaceId,
    })
    .catch(() => {
      createAlert({
        message: __(
          'An error occurred while dismissing the alert. Refresh the page and try again.',
        ),
      });
    });
};

export default () => {
  document
    .querySelectorAll('.js-targeted-message .js-close')
    .forEach((close) => close.addEventListener('click', dismissTargetedMessage));
};
