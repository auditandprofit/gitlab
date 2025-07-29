<script>
import { sprintf, s__ } from '~/locale';
import getWorkspaceStateQuery from '../graphql/queries/get_workspace_state.query.graphql';
import { WORKSPACE_STATES, GET_WORKSPACE_STATE_INTERVAL } from '../constants';

export default {
  props: {
    workspaceId: {
      type: String,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    workspace: {
      query: getWorkspaceStateQuery,
      variables() {
        return { id: this.workspaceId };
      },
      pollInterval: GET_WORKSPACE_STATE_INTERVAL,
    },
  },
  watch: {
    workspace(workspace) {
      if (workspace.actualState === WORKSPACE_STATES.terminated) {
        this.$toast.show(
          sprintf(s__('Workspaces|%{workspaceName} has been terminated.'), {
            workspaceName: workspace.name,
          }),
        );
        this.$apollo.queries.workspace.stop();
      }
    },
  },
  render() {
    return null;
  },
};
</script>
