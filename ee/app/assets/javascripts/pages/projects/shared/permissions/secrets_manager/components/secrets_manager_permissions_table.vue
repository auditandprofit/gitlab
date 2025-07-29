<script>
import { GlTab, GlTable } from '@gitlab/ui';
import { __ } from '~/locale';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';

export default {
  name: 'SecretsManagerPermissionsTable',
  components: {
    GlTab,
    GlTable,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    permissionCategory: {
      type: String,
      required: true,
    },
  },
  data() {
    return {};
  },
  computed: {
    tableFields() {
      return [
        ...(this.permissionCategory === PERMISSION_CATEGORY_USER
          ? [
              {
                key: 'user',
                label: __('User'),
              },
              {
                key: 'user-role',
                label: __('Role'),
              },
            ]
          : []),
        ...(this.permissionCategory === PERMISSION_CATEGORY_GROUP
          ? [
              {
                key: 'group',
                label: __('Group'),
              },
            ]
          : []),
        ...(this.permissionCategory === PERMISSION_CATEGORY_ROLE
          ? [
              {
                key: 'role',
                label: __('Role'),
              },
            ]
          : []),
        {
          key: 'scope',
          label: __('Scope'),
        },
        {
          key: 'expiration',
          label: __('Expiration'),
        },
        {
          key: 'access-granted',
          label: __('Access granted'),
        },
      ];
    },
    tableTitle() {
      if (this.permissionCategory === PERMISSION_CATEGORY_USER) {
        return __('Users');
      }

      if (this.permissionCategory === PERMISSION_CATEGORY_GROUP) {
        return __('Group');
      }

      return __('Roles');
    },
  },
};
</script>

<template>
  <gl-tab :title="tableTitle">
    <gl-table :items="items" :fields="tableFields" />
  </gl-tab>
</template>
