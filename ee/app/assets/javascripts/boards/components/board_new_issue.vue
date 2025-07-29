<script>
import { s__ } from '~/locale';
import BoardNewIssueFoss from '~/boards/components/board_new_issue.vue';
import { setError } from '~/boards/graphql/cache_updates';
import { formatIssueInput } from '../boards_util';
import { IterationIDs } from '../constants';

import currentIterationQuery from '../graphql/board_current_iteration.query.graphql';

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  extends: BoardNewIssueFoss,
  data() {
    return {
      currentIteration: {},
    };
  },
  apollo: {
    currentIteration: {
      query: currentIterationQuery,
      context: {
        isSingleRequest: true,
      },
      variables() {
        return {
          isGroup: this.isGroupBoard,
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data[this.boardType]?.iterations?.nodes?.[0];
      },
      skip() {
        const { iteration, iterationCadence } = this.board;
        return iteration?.id !== IterationIDs.CURRENT || iterationCadence?.id !== undefined;
      },
      error(error) {
        setError({
          error,
          message: s__('Boards|No cadence matches current iteration filter'),
        });
      },
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- This component inherits from `BoardNewIssueFoss` which calls `addNewIssueToList()` internally
    addNewIssueToList({ issueInput }) {
      const { labels, assignee, milestone, weight, iteration, iterationCadence } = this.board;
      const config = {
        labels,
        assigneeId: assignee?.id || null,
        milestoneId: milestone?.id || null,
        weight,
      };

      const statusId = this.list?.status?.id;

      const modifiedIssueInput = { ...issueInput };
      if (statusId) {
        modifiedIssueInput.statusId = statusId;
      }

      if (iteration?.id !== IterationIDs.NONE) {
        config.iterationId = iteration?.id || null;
        config.iterationCadenceId = iterationCadence?.id || null;
      }

      // When board is scoped to current iteration we need to fetch and assign a cadence to the issue being created
      if (!config.iterationCadenceId && config.iterationId === IterationIDs.CURRENT) {
        config.iterationCadenceId = this.currentIteration.iterationCadence.id;
      }

      const input = formatIssueInput(modifiedIssueInput, config);

      if (!this.isGroupBoard) {
        input.projectPath = this.fullPath;
      }

      this.$emit('addNewIssue', input);
    },
  },
};
</script>
