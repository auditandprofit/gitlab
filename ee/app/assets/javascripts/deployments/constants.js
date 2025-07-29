import { s__ } from '~/locale';

export const APPROVAL_STATUSES = {
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
};

export const ACCESS_LEVEL_DISPLAY = {
  MAINTAINER: s__('DeploymentApprovals|Maintainers'),
  DEVELOPER: s__('DeploymentApprovals|Developers + Maintainers'),
};
