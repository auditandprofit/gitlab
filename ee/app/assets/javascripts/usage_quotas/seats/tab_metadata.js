import { __ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';
import apolloProvider from '../shared/provider';

export const parseProvideData = (el) => {
  const {
    fullPath,
    namespaceId,
    namespaceName,
    isPublicNamespace,
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    maxFreeNamespaceSeats,
    explorePlansPath,
    enforcementFreeUserCapEnabled,
  } = el.dataset;

  return {
    fullPath,
    namespaceId: parseInt(namespaceId, 10),
    namespaceName,
    isPublicNamespace: parseBoolean(isPublicNamespace),
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    maxFreeNamespaceSeats: parseInt(maxFreeNamespaceSeats, 10),
    explorePlansPath,
    enforcementFreeUserCapEnabled: parseBoolean(enforcementFreeUserCapEnabled),
  };
};

export const getSeatTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector('#js-seat-usage-app');

  if (!el) return false;

  const {
    fullPath,
    namespaceId,
    namespaceName,
    isPublicNamespace,
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    maxFreeNamespaceSeats,
    explorePlansPath,
    enforcementFreeUserCapEnabled,
  } = parseProvideData(el);

  const SeatUsageApp = () => {
    const component = import(
      /* webpackChunkName: 'uq_seats' */ './components/subscription_seats.vue'
    );
    return createAsyncTabContentWrapper(component);
  };

  const seatTabMetadata = {
    title: __('Seats'),
    hash: '#seats-quota-tab',
    testid: 'seats-tab',
    component: {
      name: 'SeatUsageTab',
      apolloProvider,
      provide: {
        subscriptionHistoryHref,
        explorePlansPath,
        fullPath,
        isPublicNamespace,
        namespaceId,
        namespaceName,
        addSeatsHref,
        seatUsageExportPath,
        maxFreeNamespaceSeats,
        hasLimitedFreePlan: enforcementFreeUserCapEnabled,
      },
      render(createElement) {
        return createElement(SeatUsageApp);
      },
    },
  };

  if (includeEl) {
    seatTabMetadata.component.el = el;
  }

  return seatTabMetadata;
};
