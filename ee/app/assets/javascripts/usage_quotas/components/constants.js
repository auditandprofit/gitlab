import { s__ } from '~/locale';

export const LIMITED_ACCESS_MESSAGING = Object.freeze({
  MANAGED_BY_RESELLER: {
    title: s__('SubscriptionMangement|Your subscription is in read-only mode'),
    content: s__(
      'SubscriptionMangement|To make changes to a read-only subscription or purchase additional products, contact your GitLab Partner.',
    ),
  },
});

export const LIMITED_ACCESS_KEYS = Object.keys(LIMITED_ACCESS_MESSAGING);
