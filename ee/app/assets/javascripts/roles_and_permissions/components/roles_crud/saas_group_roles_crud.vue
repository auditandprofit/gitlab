<script>
import groupRolesQuery from '../../graphql/group_roles.query.graphql';
import RolesCrud from './roles_crud.vue';
import { showRolesFetchError, createNewCustomRoleOption } from './utils';

export default {
  components: { RolesCrud },
  inject: ['groupFullPath', 'newRolePath'],
  data() {
    return {
      roles: {},
    };
  },
  computed: {
    newRoleOptions() {
      return this.newRolePath ? [createNewCustomRoleOption(this.newRolePath)] : [];
    },
  },
  apollo: {
    roles: {
      query: groupRolesQuery,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => data.group,
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
