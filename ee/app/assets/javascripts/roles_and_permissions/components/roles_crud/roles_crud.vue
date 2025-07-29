<script>
import { GlSprintf, GlButton, GlDisclosureDropdown } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import groupRolesQuery from '../../graphql/group_roles.query.graphql';
import instanceRolesQuery from '../../graphql/instance_roles.query.graphql';
import DeleteRoleModal from '../delete_role_modal.vue';
import RolesTable from '../roles_table/roles_table.vue';
import RolesExport from '../roles_table/roles_export.vue';

export default {
  i18n: {
    roleCrudTitle: __('Roles'),
    roleCount: s__(`MemberRole|%{defaultCount} Default %{customCount} Custom`),
    roleCountAdmin: s__(`MemberRole|%{adminCount} Admin`),
    newRoleText: s__('MemberRole|New role'),
    fetchRolesError: s__('MemberRole|Failed to fetch roles.'),
    roleDeletedText: s__('MemberRole|Role successfully deleted.'),
  },
  components: {
    GlSprintf,
    GlButton,
    GlDisclosureDropdown,
    RolesTable,
    DeleteRoleModal,
    RolesExport,
    CrudComponent,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagMixin()],
  inject: ['groupFullPath', 'newRolePath', 'isSaas'],
  data() {
    return {
      rolesData: null,
      roleToDelete: null,
    };
  },
  apollo: {
    rolesData: {
      query() {
        return this.groupFullPath ? groupRolesQuery : instanceRolesQuery;
      },
      variables() {
        return this.groupFullPath ? { fullPath: this.groupFullPath } : { isSaas: this.isSaas };
      },
      update(data) {
        return this.groupFullPath ? data.group : data;
      },
      error() {
        createAlert({ message: this.$options.i18n.fetchRolesError, dismissible: false });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.rolesData.loading;
    },
    defaultRoles() {
      return this.rolesData?.standardRoles?.nodes || [];
    },
    customRoles() {
      return this.rolesData?.memberRoles?.nodes || [];
    },
    adminRoles() {
      return this.rolesData?.adminMemberRoles?.nodes || [];
    },
    roles() {
      return [...this.defaultRoles, ...this.customRoles, ...this.adminRoles];
    },
    canExportRoles() {
      // Check that the backend feature is enabled and that the current user can export members.
      return (
        this.glFeatures.membersPermissionsDetailedExport && this.glAbilities.exportGroupMemberships
      );
    },
    canCreateAdminRole() {
      return this.glFeatures.customAdminRoles && this.newRolePath && !this.groupFullPath;
    },
    newRoleItems() {
      return [
        {
          text: s__('MemberRole|Member role'),
          href: this.newRolePath,
          description: s__(
            'MemberRole|Create a role to manage member permissions for groups and projects.',
          ),
        },
        {
          text: s__('MemberRole|Admin role'),
          href: `${this.newRolePath}?admin`,
          description: s__('MemberRole|Create a role to manage permissions in the Admin area.'),
        },
      ];
    },
  },
  methods: {
    processRoleDeletion() {
      this.roleToDelete = null;
      this.$toast.show(this.$options.i18n.roleDeletedText);
      this.$apollo.queries.rolesData.refetch();
    },
  },
  userPermissionsDocPath: helpPagePath('user/permissions'),
};
</script>

<template>
  <crud-component>
    <template #title>
      <div>
        {{ $options.i18n.roleCrudTitle }}

        <span data-testid="role-counts" class="gl-ml-2 gl-text-sm gl-font-normal gl-text-subtle">
          <gl-sprintf :message="$options.i18n.roleCount">
            <template #defaultCount>
              <span class="gl-font-bold">{{ defaultRoles.length }}</span>
            </template>
            <template #customCount>
              <span class="gl-ml-3 gl-font-bold">{{ customRoles.length }}</span>
            </template>
          </gl-sprintf>
          <gl-sprintf v-if="glFeatures.customAdminRoles" :message="$options.i18n.roleCountAdmin">
            <template #adminCount>
              <span class="gl-ml-3 gl-font-bold">{{ adminRoles.length }}</span>
            </template>
          </gl-sprintf>
        </span>
      </div>
    </template>

    <template #actions>
      <roles-export v-if="canExportRoles" />

      <gl-disclosure-dropdown
        v-if="canCreateAdminRole"
        :items="newRoleItems"
        :toggle-text="$options.i18n.newRoleText"
        placement="bottom-end"
        fluid-width
      >
        <template #list-item="{ item }">
          <div class="gl-mx-3 gl-w-34">
            <div class="gl-font-bold">{{ item.text }}</div>
            <div class="gl-mt-2 gl-text-subtle">{{ item.description }}</div>
          </div>
        </template>
      </gl-disclosure-dropdown>
      <gl-button v-else-if="newRolePath" :href="newRolePath" size="small">
        {{ $options.i18n.newRoleText }}
      </gl-button>
    </template>

    <roles-table :roles="roles" :busy="isLoading" @delete-role="roleToDelete = $event" />

    <delete-role-modal
      :role="roleToDelete"
      @deleted="processRoleDeletion"
      @close="roleToDelete = null"
    />
  </crud-component>
</template>
