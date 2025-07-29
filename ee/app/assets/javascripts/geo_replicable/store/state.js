import { parseBoolean } from '~/lib/utils/common_utils';

const createState = ({
  titlePlural,
  graphqlFieldName,
  graphqlMutationRegistryClass,
  verificationEnabled,
  geoCurrentSiteId,
  geoTargetSiteId,
}) => ({
  titlePlural,
  graphqlFieldName,
  graphqlMutationRegistryClass,
  verificationEnabled: parseBoolean(verificationEnabled),
  geoCurrentSiteId,
  geoTargetSiteId,
  isLoading: false,

  replicableItems: [],
  paginationData: {
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: '',
    endCursor: '',
  },

  searchFilter: '',
  statusFilter: '',
});
export default createState;
