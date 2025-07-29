import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { relayStylePagination } from '@apollo/client/utilities';
import { makeVar } from '@apollo/client/core';
import createDefaultClient from '~/lib/graphql';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import vulnerabilitiesOverTimeResolvers from './resolvers/vulnerabilities_over_time_resolvers';

Vue.use(VueApollo);

let containerScanningForRegistry;

// Please see this comment for an explanation of what this does:
// https://gitlab.com/gitlab-org/gitlab/-/merge_requests/86408#note_942523549
export const cacheConfig = {
  typePolicies: {
    Group: {
      fields: {
        projects: relayStylePagination(['includeSubgroups', 'ids', 'search']),
      },
    },
    InstanceSecurityDashboard: {
      fields: {
        projects: relayStylePagination(['search']),
      },
    },
    Project: {
      fields: {
        containerScanningForRegistry: {
          read(_, { variables }) {
            if (!containerScanningForRegistry) {
              containerScanningForRegistry = makeVar({
                __typename: 'LocalContainerScanningForRegistry',
                isEnabled: false,
                isVisible: false,
              });

              axios
                .get(variables.securityConfigurationPath)
                .then(({ data }) => {
                  containerScanningForRegistry({
                    __typename: 'LocalContainerScanningForRegistry',
                    isEnabled: data.container_scanning_for_registry_enabled,
                    isVisible: true,
                  });
                })
                .catch((e) => {
                  if (e.response?.status === HTTP_STATUS_FORBIDDEN) {
                    return containerScanningForRegistry({
                      __typename: 'LocalContainerScanningForRegistry',
                      isEnabled: false,
                      isVisible: false,
                    });
                  }
                  return Sentry.captureException(e);
                });
            }

            return containerScanningForRegistry();
          },
        },
      },
    },
  },
};

// Create Apollo client with cache config and security dashboard local resolvers
export const defaultClient = createDefaultClient(vulnerabilitiesOverTimeResolvers, { cacheConfig });

export default new VueApollo({ defaultClient });
