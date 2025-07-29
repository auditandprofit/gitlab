<script>
import instanceRolesQuery from '../../graphql/instance_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewAdminRoleOption } from './utils';

export default {
  components: { RolesCrud },
  inject: ['newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    newRoleOptions() {
      return this.newRolePath ? [createNewAdminRoleOption(this.newRolePath)] : [];
    },
  },
  apollo: {
    roles: {
      query: instanceRolesQuery,
      variables: { isSaas: true },
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
