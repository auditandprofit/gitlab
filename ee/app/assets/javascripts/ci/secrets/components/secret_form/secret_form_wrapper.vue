<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, s__ } from '~/locale';
import {
  getGroupEnvironments,
  getProjectEnvironments,
  ENVIRONMENT_FETCH_ERROR,
  ENVIRONMENT_QUERY_LIMIT,
  mapEnvironmentNames,
} from '~/ci/common/private/ci_environments_dropdown';
import { ENTITY_PROJECT, FAILED_TO_LOAD_ERROR_MESSAGE } from '../../constants';
import getSecretDetailsQuery from '../../graphql/queries/get_secret_details.query.graphql';
import SecretForm from './secret_form.vue';

const i18n = {
  descriptionGroup: s__(
    'Secrets|Add a new secret to the group by following the instructions in the form below.',
  ),
  descriptionProject: s__(
    'Secrets|Add a new secret to the project by following the instructions in the form below.',
  ),
  titleNew: s__('Secrets|New secret'),
};

export default {
  name: 'SecretFormWrapper',
  components: {
    GlLoadingIcon,
    SecretForm,
  },
  props: {
    entity: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
    secretName: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      environments: [],
      secretData: null,
    };
  },
  apollo: {
    environments: {
      query() {
        return this.entity === ENTITY_PROJECT ? getProjectEnvironments : getGroupEnvironments;
      },
      variables() {
        return {
          first: ENVIRONMENT_QUERY_LIMIT,
          fullPath: this.fullPath,
          search: '',
        };
      },
      update(data) {
        if (this.entity === ENTITY_PROJECT) {
          return mapEnvironmentNames(data.project?.environments?.nodes || []);
        }

        return mapEnvironmentNames(data.group?.environmentScopes?.nodes || []);
      },
      error() {
        createAlert({ message: ENVIRONMENT_FETCH_ERROR });
      },
    },
    secretData: {
      skip() {
        return !this.isEditing;
      },
      query: getSecretDetailsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          name: this.secretName,
        };
      },
      update(data) {
        return data.projectSecret || null;
      },
      error() {
        createAlert({ message: FAILED_TO_LOAD_ERROR_MESSAGE });
      },
    },
  },
  computed: {
    areEnvironmentsLoading() {
      return this.$apollo.queries.environments.loading;
    },
    isSecretLoading() {
      return this.isEditing && this.$apollo.queries.secretData.loading;
    },
    pageDescription() {
      if (this.entity === ENTITY_PROJECT) {
        return this.$options.i18n.descriptionProject;
      }

      return this.$options.i18n.descriptionGroup;
    },
    pageTitle() {
      if (this.isEditing) {
        return sprintf(s__('Secrets|Edit %{name}'), { name: this.secretName });
      }

      return this.$options.i18n.titleNew;
    },
  },
  methods: {
    searchEnvironment(searchTerm) {
      this.$apollo.queries.environments.refetch({ search: searchTerm });
    },
  },
  i18n,
};
</script>
<template>
  <div>
    <h1 class="page-title gl-text-size-h-display">{{ pageTitle }}</h1>
    <p v-if="!isEditing">{{ pageDescription }}</p>
    <gl-loading-icon
      v-if="isSecretLoading"
      data-testid="secret-loading-icon"
      size="lg"
      class="gl-mt-6"
    />
    <secret-form
      v-else
      :are-environments-loading="areEnvironmentsLoading"
      :environments="environments"
      :full-path="fullPath"
      :is-editing="isEditing"
      :secret-data="secretData"
      @search-environment="searchEnvironment"
      v-on="$listeners"
    />
  </div>
</template>
