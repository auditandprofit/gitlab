<script>
import mostActiveRunnersQuery from 'ee/ci/runner/graphql/performance/most_active_runners.query.graphql';
import RunnerActiveList from 'ee/ci/runner/components/runner_active_list.vue';

import { captureException } from '~/ci/runner/sentry_utils';
import { fetchPolicies } from '~/lib/graphql';
import { createAlert } from '~/alert';
import { I18N_FETCH_ERROR } from '~/ci/runner/constants';

export default {
  name: 'AdminRunnerActiveList',
  components: {
    RunnerActiveList,
  },
  data() {
    return {
      activeRunners: [],
    };
  },
  apollo: {
    activeRunners: {
      query: mostActiveRunnersQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      update({ runners }) {
        const items = runners?.nodes || [];
        return (
          items
            // The backend does not filter out inactive runners, but
            // showing them can be confusing for users. Ignore runners
            // with no active jobs.
            .filter((item) => item.runningJobCount > 0)
            .map((item) => {
              const { adminUrl, ...runner } = item;
              return {
                ...runner,
                webUrl: adminUrl,
              };
            })
        );
      },
      error(error) {
        createAlert({ message: I18N_FETCH_ERROR });

        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.activeRunners.loading;
    },
  },
};
</script>
<template>
  <runner-active-list :active-runners="activeRunners" :loading="loading" />
</template>
