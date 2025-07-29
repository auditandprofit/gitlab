<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import instanceRolesQuery from '../../graphql/instance_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewCustomRoleOption, createNewAdminRoleOption } from './utils';

export default {
  components: { RolesCrud },
  mixins: [glFeatureFlagsMixin()],
  inject: ['newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    newRoleOptions() {
      if (!this.newRolePath) return [];

      const items = [createNewCustomRoleOption(this.newRolePath)];
      // Add the ability to create admin roles if the feature is enabled.
      if (this.glFeatures.customAdminRoles) {
        items.push(createNewAdminRoleOption(this.newRolePath));
      }

      return items;
    },
  },
  apollo: {
    roles: {
      query: instanceRolesQuery,
      variables: { isSaas: false },
      update: (data) => data,
      error: showRolesFetchError,
    },
  },
};
</script>

<template>
  <roles-crud
    :roles="roles"
    :loading="$apollo.queries.roles.loading"
    :new-role-options="newRoleOptions"
  />
</template>
