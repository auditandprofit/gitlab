<script>
import {
  GlAvatarLabeled,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlDatepicker,
  GlForm,
  GlFormGroup,
  GlModal,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { createAlert } from '~/alert';
import { getDateInFuture, toISODateFormat } from '~/lib/utils/datetime_utility';
import {
  fetchGroupsWithProjectAccess,
  fetchUsers,
} from '~/vue_shared/components/list_selector/api';
import {
  ACCESS_LEVEL_NO_ACCESS_INTEGER,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  BASE_ROLES,
} from '~/access_level/constants';
import { __, s__ } from '~/locale';
import { CONFIG, GROUPS_TYPE, USERS_TYPE } from '~/vue_shared/components/list_selector/constants';
import createSecretsPermission from '../graphql/create_secrets_permission.mutation.graphql';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';

export default {
  name: 'SecretsManagerPermissionsModal',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlModal,
  },
  inject: ['fullPath', 'projectId'],
  props: {
    permissionCategory: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      expiration: null,
      isListboxLoading: false,
      isSubmitting: false,
      listboxItems: [],
      principal: null,
      scope: {
        read: false,
        create: false,
        update: false,
        delete: false,
      },
      selectedListboxItem: '',
    };
  },
  computed: {
    isCategoryUser() {
      return this.permissionCategory === PERMISSION_CATEGORY_USER;
    },
    isCategoryGroup() {
      return this.permissionCategory === PERMISSION_CATEGORY_GROUP;
    },
    isCategoryRole() {
      return this.permissionCategory === PERMISSION_CATEGORY_ROLE;
    },
    isSubmittable() {
      return this.principal !== null && this.selectedPermissions.length > 0;
    },
    listboxTitle() {
      if (this.isCategoryUser) {
        return __('Username or name');
      }
      return __('Group');
    },
    listboxToggleText() {
      if (!this.principal) {
        return __('Select');
      }

      if (this.isCategoryUser) {
        return this.principal.name;
      }

      return this.principal.text;
    },
    minExpirationDate() {
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    modalOptions() {
      return {
        actionPrimary: {
          text: __('Add'),
          attributes: {
            disabled: !this.isSubmittable,
            loading: this.isSubmitting,
            variant: 'confirm',
          },
        },
        actionSecondary: {
          text: __('Cancel'),
          attributes: {
            variant: 'default',
          },
        },
      };
    },
    modalTitle() {
      if (this.isCategoryUser) {
        return __('Add user');
      }

      if (this.isCategoryGroup) {
        return __('Add group');
      }

      return __('Add role');
    },
    rolesList() {
      const excludedRoles = [
        ACCESS_LEVEL_NO_ACCESS_INTEGER,
        ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
        ACCESS_LEVEL_GUEST_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];

      return BASE_ROLES.filter((role) => !excludedRoles.includes(role.accessLevel));
    },
    selectedPermissions() {
      return Object.keys(this.scope).filter((permission) => this.scope[permission]);
    },
  },
  methods: {
    async createPermission() {
      this.isSubmitting = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createSecretsPermission,
          variables: {
            projectPath: this.fullPath,
            principal: {
              id: this.isCategoryRole ? this.principal.accessLevel : this.principal.id,
              type: this.permissionCategory,
            },
            permissions: this.selectedPermissions,
            expiredAt: this.expiration ? toISODateFormat(this.expiration) : null,
          },
        });

        const error = data.secretPermissionUpdate.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.$toast.show(s__('Secrets|Secret Manager permissions were successfully updated.'));
      } catch (e) {
        createAlert({
          message: __('Something went wrong on our end. Please try again.'),
          captureError: true,
          error: e,
        });
      } finally {
        this.hideModal();
        this.isSubmitting = false;
      }
    },
    debouncedSearchListbox: debounce(function debouncedSearch(search) {
      this.searchListbox(search);
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    async searchListbox(search) {
      try {
        this.isListboxLoading = true;
        if (this.isCategoryUser) {
          this.listboxItems = await fetchUsers(this.fullPath, search);
        }

        if (this.isCategoryGroup) {
          this.listboxItems = await fetchGroupsWithProjectAccess(this.projectId, search);
        }
      } catch (e) {
        createAlert({
          message: __('An error occurred while fetching. Please try again.'),
          captureError: true,
          error: e,
        });
      } finally {
        this.isListboxLoading = false;
      }
    },
    selectListboxItem(listboxItem) {
      this.selectedListboxItem = listboxItem;
      const sourceList = this.isCategoryRole ? this.rolesList : this.listboxItems;
      [this.principal] = sourceList.filter((item) => item.value === listboxItem);
    },
    hideModal() {
      this.listboxItems = [];
      this.principal = null;
      this.expiration = null;
      this.selectedListboxItem = '';
      this.scope = {
        read: false,
        create: false,
        update: false,
        delete: false,
      };

      this.$emit('hide');
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  GROUP_LISTBOX: CONFIG[GROUPS_TYPE],
  USERS_LISTBOX: CONFIG[USERS_TYPE],
};
</script>

<template>
  <gl-modal
    :visible="permissionCategory !== null"
    :title="modalTitle"
    :action-primary="modalOptions.actionPrimary"
    :action-secondary="modalOptions.actionSecondary"
    modal-id="secrets-manager-permissions-modal"
    @primary.prevent="createPermission"
    @secondary="hideModal"
    @canceled="hideModal"
    @hidden="hideModal"
  >
    <gl-form>
      <gl-form-group
        v-if="isCategoryUser || isCategoryGroup"
        label-for="secret-permission-principal"
        :label="listboxTitle"
      >
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="listboxItems"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          :search-placeholder="isCategoryUser ? __('Search users...') : __('Search groups...')"
          :searching="isListboxLoading"
          searchable
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
          @search="debouncedSearchListbox"
          @shown="searchListbox"
        >
          <template #list-item="{ item }">
            <gl-avatar-labeled
              :label="item.name"
              :sub-label="item.username"
              :src="item.avatarUrl"
              :entity-name="item.name"
              :size="32"
            />
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
      <gl-form-group v-else label-for="secret-permission-principal" :label="__('Role')">
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="rolesList"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
        />
      </gl-form-group>
      <gl-form-group label-for="secret-permission-expiration" :label="__('Access expiration date')">
        <gl-datepicker
          id="secret-expiration"
          v-model="expiration"
          optional
          :placeholder="$options.datePlaceholder"
          :min-date="minExpirationDate"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Scopes')"
        :label-description="
          s__(
            'Secrets|Select the access scopes to grant to this user for the Secret Manager and related API endpoints.',
          )
        "
      >
        <gl-form-checkbox v-model="scope.read" class="-gl-mb-4">
          {{ __('Read') }}
          <p class="gl-text-subtle">
            {{
              s__('Secrets|Can authenticate with the Secrets Manager and related API endpoints.')
            }}
            {{ s__('Secrets|Can read secret metadata but not the secret value.') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="scope.create" class="-gl-mb-4" :disabled="!scope.read">
          {{ __('Create') }}
          <p class="gl-text-subtle">
            {{ s__('Secrets|Can add new secrets') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="scope.update" class="-gl-mb-4" :disabled="!scope.read">
          {{ __('Update') }}
          <p class="gl-text-subtle">
            {{ s__('Secrets|Can update details of existing secrets.') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="scope.delete" class="-gl-mb-4" :disabled="!scope.read">
          {{ __('Delete') }}
          <p class="gl-text-subtle">
            {{ s__('Secrets|Can permanently delete secrets.') }}
          </p>
        </gl-form-checkbox>
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
