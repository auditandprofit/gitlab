import { s__ } from '~/locale';
import { getTokenConfigs } from '~/admin/users/constants';

export {
  SOLO_OWNED_ORGANIZATIONS_EMPTY,
  I18N_USER_ACTIONS,
  SOLO_OWNED_ORGANIZATIONS_REQUESTED_COUNT,
} from '~/admin/users/constants';

export const TOKEN_CONFIGS = getTokenConfigs([
  { value: 'admins', title: s__('AdminUsers|Administrator') },
  { value: 'auditors', title: s__('AdminUsers|Auditor') },
  { value: 'external', title: s__('AdminUsers|External') },
]);
