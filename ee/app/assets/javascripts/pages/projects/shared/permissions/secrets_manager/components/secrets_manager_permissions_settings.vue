<script>
import { GlCollapsibleListbox, GlTabs } from '@gitlab/ui';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';
import PermissionsModal from './secrets_manager_permissions_modal.vue';
import PermissionsTable from './secrets_manager_permissions_table.vue';

export default {
  name: 'SecretsManagerPermissionsSettings',
  components: {
    CrudComponent,
    GlCollapsibleListbox,
    GlTabs,
    PermissionsModal,
    PermissionsTable,
  },
  props: {
    canManageSecretsManager: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedPermissionCategory: null,
      secretsPermissions: [],
    };
  },
  methods: {
    resetSelectedPermissionCategory() {
      this.selectedPermissionCategory = null;
    },
  },
  CREATE_OPTIONS: [
    {
      text: __('Users'),
      value: PERMISSION_CATEGORY_USER,
    },
    {
      text: __('Groups'),
      value: PERMISSION_CATEGORY_GROUP,
    },
    {
      text: __('Roles'),
      value: PERMISSION_CATEGORY_ROLE,
    },
  ],
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
};
</script>

<template>
  <div>
    <permissions-modal
      :permission-category="selectedPermissionCategory"
      @hide="resetSelectedPermissionCategory"
    />
    <crud-component :title="s__('Secrets|Secret manager user permissions')" class="gl-mt-5">
      <template #actions>
        <gl-collapsible-listbox
          v-if="canManageSecretsManager"
          v-model="selectedPermissionCategory"
          :items="$options.CREATE_OPTIONS"
          :toggle-text="__('Add')"
          size="small"
        />
      </template>
      <template #default>
        <gl-tabs>
          <permissions-table
            :items="secretsPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_USER"
          />
          <permissions-table
            :items="secretsPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_GROUP"
          />
          <permissions-table
            :items="secretsPermissions"
            :permission-category="$options.PERMISSION_CATEGORY_ROLE"
          />
        </gl-tabs>
      </template>
    </crud-component>
  </div>
</template>
