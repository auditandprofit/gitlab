<script>
import { __, sprintf } from '~/locale';
import GetGroupOrProjectQuery from '../graphql/get_group_or_project.query.graphql';

const NAMESPACE_LOAD_ERROR = __('Failed to fetch Namespace: %{fullPath}');

/**
 * Renderless component that resolves a namespace as a group or project
 * given its path name as a property
 */
export default {
  name: 'GroupOrProjectProvider',
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  emits: ['done', 'error'],
  data() {
    return {
      namespace: {},
    };
  },
  apollo: {
    namespace: {
      query: GetGroupOrProjectQuery,
      variables() {
        return { fullPath: this.fullPath };
      },
      update(response) {
        const { group = null, project = null } = response;
        return { group, project, isProject: Boolean(project) };
      },
      error() {
        this.$emit('error', sprintf(NAMESPACE_LOAD_ERROR, { fullPath: this.fullPath }));
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.namespace.loading;
    },
  },
  render() {
    if (this.loading) {
      return this.$scopedSlots.default({ isNamespaceLoading: this.loading });
    }

    const { group, project, isProject } = this.namespace;
    this.$emit('done', { group, project, isProject });

    return this.$scopedSlots.default({
      group,
      project,
      isProject,
      isNamespaceLoading: false,
    });
  },
};
</script>
