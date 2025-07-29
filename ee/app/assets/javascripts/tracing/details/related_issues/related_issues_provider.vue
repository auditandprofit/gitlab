<script>
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import getTraceRelatedIssues from './graphql/get_trace_related_issues.query.graphql';

export default {
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    traceId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      relatedIssues: [],
      error: null,
    };
  },
  apollo: {
    relatedIssues: {
      query: getTraceRelatedIssues,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
          traceId: this.traceId,
        };
      },
      update(data) {
        const links = data.project?.observabilityTracesLinks?.nodes || [];

        return parseGraphQLIssueLinksToRelatedIssues(links);
      },
      error(error) {
        this.error = error;
      },
    },
  },
  render() {
    if (!this.$scopedSlots.default) return null;

    return this.$scopedSlots.default({
      issues: this.relatedIssues,
      loading: this.$apollo.loading,
      error: this.error,
    });
  },
};
</script>
