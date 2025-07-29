<script>
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import { GRAPHQL_METRIC_TYPE } from '../../constants';
import getMetricsRelatedIssues from './graphql/get_metrics_related_issues.query.graphql';

export default {
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    metricName: {
      type: String,
      required: true,
    },
    metricType: {
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
      query: getMetricsRelatedIssues,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
          metricName: this.metricName,
          metricType: GRAPHQL_METRIC_TYPE[this.metricType.toLowerCase()],
        };
      },
      update(data) {
        const links = data.project?.observabilityMetricsLinks?.nodes || [];
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
