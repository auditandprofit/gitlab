import { s__ } from '~/locale';

const GEO_SHARED_STATUS_STATES = {
  PENDING: {
    title: s__('Geo|Pending'),
    value: 'PENDING',
    variant: 'warning',
    icon: 'status_preparing',
  },
  STARTED: {
    title: s__('Geo|Started'),
    value: 'STARTED',
    variant: 'info',
    icon: 'status_running',
  },
  FAILED: {
    title: s__('Geo|Failed'),
    value: 'FAILED',
    variant: 'danger',
    icon: 'status_failed',
  },
  UNKNOWN: {
    title: s__('Geo|Unknown'),
    value: null,
    variant: 'muted',
    icon: 'status_notfound',
  },
};

export const REPLICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SYNCED: {
    title: s__('Geo|Synced'),
    value: 'SYNCED',
    variant: 'success',
    icon: 'status_success',
  },
};

export const VERIFICATION_STATUS_STATES = {
  ...GEO_SHARED_STATUS_STATES,
  SUCCEEDED: {
    title: s__('Geo|Succeeded'),
    value: 'SUCCEEDED',
    variant: 'success',
    icon: 'status_success',
  },
  DISABLED: {
    title: s__('Geo|Disabled'),
    value: 'DISABLED',
    variant: 'neutral',
    icon: 'status_canceled',
  },
};

export const ACTION_TYPES = {
  REVERIFY: 'REVERIFY',
  RESYNC: 'RESYNC',
};
