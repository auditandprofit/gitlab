<script>
import {
  GlFormCheckbox,
  GlLoadingIcon,
  GlTable,
  GlSprintf,
  GlLink,
  GlAlert,
  GlBadge,
} from '@gitlab/ui';
import { pull } from 'lodash';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { BASE_ROLES } from '~/access_level/constants';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { isPermissionPreselected } from '../../utils';
import memberPermissionsQuery from '../../graphql/member_role_permissions.query.graphql';
import adminPermissionsQuery from '../../graphql/admin_role/role_permissions.query.graphql';

export const FIELDS = [
  { key: 'checkbox', label: __('Select') },
  { key: 'name', label: s__('MemberRole|Permission') },
  { key: 'description', label: s__('MemberRole|Description') },
].map((field) => ({ ...field, class: '!gl-pt-6 !gl-pb-6' }));

export default {
  i18n: {
    customPermissionsLabel: s__('MemberRole|Custom permissions'),
    customPermissionsDescription: s__(
      'MemberRole|Learn more about %{linkStart}available custom permissions%{linkEnd}.',
    ),
    permissionsFetchError: s__('MemberRole|Could not fetch available permissions.'),
    permissionsSelected: s__('MemberRole|%{count} of %{total} permissions selected'),
    permissionsSelectionError: s__('MemberRole|Select at least one permission.'),
    badgeText: s__('MemberRole|Added from %{role}'),
  },
  components: {
    GlFormCheckbox,
    GlLoadingIcon,
    GlLink,
    GlSprintf,
    GlTable,
    GlAlert,
    GlBadge,
    CrudComponent,
  },
  inject: ['isAdminRole'],
  model: {
    prop: 'permissions',
    event: 'change',
  },
  props: {
    permissions: {
      type: Array,
      required: true,
    },
    isValid: {
      type: Boolean,
      required: true,
    },
    selectedBaseRole: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      availablePermissions: [],
    };
  },
  apollo: {
    availablePermissions: {
      query() {
        return this.isAdminRole ? adminPermissionsQuery : memberPermissionsQuery;
      },
      update(data) {
        return data.memberRolePermissions?.nodes || [];
      },
      error() {
        this.availablePermissions = [];
      },
    },
  },
  computed: {
    docsPath() {
      return helpPagePath('user/custom_roles/abilities');
    },
    isLoadingPermissions() {
      return this.$apollo.queries.availablePermissions.loading;
    },
    isErrorLoadingPermissions() {
      return !this.isLoadingPermissions && !this.hasAvailablePermissions;
    },
    hasAvailablePermissions() {
      return this.availablePermissions.length > 0;
    },
    isSomePermissionsSelected() {
      return this.permissions.length > 0 && !this.isAllPermissionsSelected;
    },
    isAllPermissionsSelected() {
      return (
        !this.isLoadingPermissions && this.permissions.length >= this.selectablePermissions.length
      );
    },
    parentPermissionsLookup() {
      return this.selectablePermissions.reduce((acc, { value, requirements }) => {
        const required = this.getSelectableValues(requirements);
        if (required?.length) {
          acc[value] = required;
        }

        return acc;
      }, {});
    },
    childPermissionsLookup() {
      return this.selectablePermissions.reduce((acc, { value, requirements }) => {
        this.getSelectableValues(requirements)?.forEach((requirement) => {
          // Create the array if it doesn't exist, then add the requirement to it.
          acc[requirement] = acc[requirement] || [];
          acc[requirement].push(value);
        });

        return acc;
      }, {});
    },
    permissionsList() {
      return this.availablePermissions.map((permission) => {
        const isPreselected = isPermissionPreselected(permission, this.selectedBaseRole);

        return {
          ...permission,
          checked: this.permissions.includes(permission.value) || isPreselected,
          disabled: isPreselected,
        };
      });
    },
    baseRoleName() {
      return BASE_ROLES.find(({ value }) => value === this.selectedBaseRole)?.text;
    },
    selectablePermissions() {
      return this.permissionsList.filter((item) => !item.disabled);
    },
    selectablePermissionValues() {
      return new Set(this.selectablePermissions.map(({ value }) => value));
    },
    checkedPermissionsCount() {
      return this.permissionsList.filter(({ checked }) => checked).length;
    },
  },
  methods: {
    updatePermissions({ value, disabled }) {
      if (disabled) return;

      const selected = [...this.permissions];

      if (selected.includes(value)) {
        // Permission is being removed, remove it and deselect any child permissions.
        pull(selected, value);
        this.deselectChildPermissions(value, selected);
      } else {
        // Permission is being added, select it and select any parent permissions.
        selected.push(value);
        this.selectParentPermissions(value, selected);
      }

      this.emitPermissionsUpdate(selected);
    },
    toggleAllPermissions() {
      const permissions = this.isAllPermissionsSelected ? [] : this.selectablePermissions;
      this.emitPermissionsUpdate(permissions.map(({ value }) => value));
    },
    emitPermissionsUpdate(permissions) {
      this.$emit('change', permissions);
    },
    selectParentPermissions(permission, selected) {
      const parentPermissions = this.parentPermissionsLookup[permission];

      parentPermissions?.forEach((parent) => {
        // Only select the parent permission if it's not selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (!selected.includes(parent)) {
          selected.push(parent);
          this.selectParentPermissions(parent, selected);
        }
      });
    },
    deselectChildPermissions(permission, selected) {
      const childPermissions = this.childPermissionsLookup[permission];

      childPermissions?.forEach((child) => {
        // Only unselect the child permission if it's already selected. This prevents an infinite loop if there are
        // circular dependencies, i.e. A depends on B and B depends on A.
        if (selected.includes(child)) {
          pull(selected, child);
          this.deselectChildPermissions(child, selected);
        }
      });
    },
    getSelectableValues(values) {
      return values?.filter((value) => this.selectablePermissionValues.has(value));
    },
  },
  FIELDS,
};
</script>

<template>
  <crud-component
    :title="$options.i18n.customPermissionsLabel"
    class="gl-mb-5"
    title-class="gl-flex-wrap"
  >
    <template v-if="hasAvailablePermissions" #count>
      <span data-testid="permissions-selected-message">
        <gl-sprintf :message="$options.i18n.permissionsSelected">
          <template #count>{{ checkedPermissionsCount }}</template>
          <template #total>{{ availablePermissions.length }}</template>
        </gl-sprintf>
      </span>
    </template>

    <template v-if="!isAdminRole || !isValid" #description>
      <span v-if="!isAdminRole" data-testid="learn-more">
        <gl-sprintf :message="$options.i18n.customPermissionsDescription">
          <template #link="{ content }">
            <gl-link :href="docsPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </span>

      <p v-if="!isValid" class="gl-mb-0 gl-mt-2 gl-text-base gl-text-danger">
        {{ $options.i18n.permissionsSelectionError }}
      </p>
    </template>

    <gl-alert v-if="isErrorLoadingPermissions" :dismissible="false" variant="danger">
      {{ $options.i18n.permissionsFetchError }}
    </gl-alert>

    <gl-table
      v-else
      :items="permissionsList"
      :fields="$options.FIELDS"
      :busy="isLoadingPermissions"
      selected-variant=""
      selectable
      stacked="sm"
      @row-clicked="updatePermissions"
    >
      <template #table-busy>
        <gl-loading-icon size="md" />
      </template>

      <template #head(checkbox)>
        <gl-form-checkbox
          :disabled="isLoadingPermissions"
          :checked="isAllPermissionsSelected"
          :indeterminate="isSomePermissionsSelected"
          class="gl-min-h-0"
          data-testid="permission-checkbox-all"
          @change="toggleAllPermissions"
        />
      </template>

      <template #cell(checkbox)="{ item }">
        <gl-form-checkbox
          :disabled="item.disabled"
          :checked="item.checked"
          class="gl-min-h-0"
          data-testid="permission-checkbox"
          @change="updatePermissions(item)"
        />
      </template>

      <template #cell(name)="{ item }">
        <span :class="{ 'gl-text-danger': !isValid }" class="md:gl-whitespace-nowrap">
          {{ item.name }}

          <gl-badge v-if="item.disabled" variant="info" class="gl-ml-2">
            <gl-sprintf :message="$options.i18n.badgeText">
              <template #role>{{ baseRoleName }}</template>
            </gl-sprintf>
          </gl-badge>
        </span>
      </template>
    </gl-table>
  </crud-component>
</template>
