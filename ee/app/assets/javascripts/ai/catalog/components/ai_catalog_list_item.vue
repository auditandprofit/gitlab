<script>
import {
  GlAvatar,
  GlBadge,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlMarkdown,
  GlTooltipDirective,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__ } from '~/locale';
import {
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_RUN_ROUTE,
  AI_CATALOG_SHOW_QUERY_PARAM,
} from '../router/constants';
import { ENUM_TO_NAME_MAP } from '../constants';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlAvatar,
    GlBadge,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlIcon,
    GlLink,
    GlMarkdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    formattedItemId() {
      return getIdFromGraphQLId(this.item.id);
    },
    actionItems() {
      return [
        {
          text: s__('AICatalog|Test Run'),
          to: {
            name: AI_CATALOG_AGENTS_RUN_ROUTE,
            params: { id: this.formattedItemId },
          },
          icon: 'rocket-launch',
        },
        {
          text: s__('AICatalog|Edit'),
          to: {
            name: AI_CATALOG_AGENTS_EDIT_ROUTE,
            params: { id: this.formattedItemId },
          },
          icon: 'pencil',
        },
      ];
    },
    showItemRoute() {
      return {
        name: this.$route.name,
        query: { [AI_CATALOG_SHOW_QUERY_PARAM]: this.formattedItemId },
      };
    },
  },
  ENUM_TO_NAME_MAP,
};
</script>

<template>
  <li
    data-testid="ai-catalog-list-item"
    class="gl-flex gl-items-center gl-justify-between gl-border-b-1 gl-border-default gl-py-3 gl-text-subtle gl-border-b-solid"
  >
    <div class="gl-flex gl-items-center">
      <gl-avatar
        :alt="`${item.name} avatar`"
        :entity-name="item.name"
        :size="48"
        class="gl-mr-4 gl-self-start"
      />
      <div class="gl-flex gl-grow gl-flex-col gl-gap-1">
        <div class="gl-mb-1 gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <gl-link :to="showItemRoute" @click="$emit('select-item')">
            {{ item.name }}
          </gl-link>
          <gl-badge variant="neutral" class="gl-self-center">
            {{ $options.ENUM_TO_NAME_MAP[item.itemType] }}
          </gl-badge>
        </div>

        <div v-if="item.description" class="gl-line-clamp-2 gl-break-words gl-text-default">
          <gl-markdown compact class="gl-text-sm">{{ item.description }}</gl-markdown>
        </div>
      </div>
    </div>
    <gl-disclosure-dropdown
      :toggle-text="__('More actions')"
      category="tertiary"
      icon="ellipsis_v"
      no-caret
      text-sr-only
    >
      <gl-disclosure-dropdown-group>
        <gl-disclosure-dropdown-item
          v-for="(actionItem, index) in actionItems"
          :key="index"
          :item="actionItem"
        >
          <template #list-item>
            <span>
              <gl-icon
                :name="actionItem.icon"
                class="gl-mr-2"
                variant="subtle"
                aria-hidden="true"
              />
              {{ actionItem.text }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
      <gl-disclosure-dropdown-group bordered>
        <gl-disclosure-dropdown-item variant="danger" @action="$emit('delete')">
          <template #list-item>
            <span>
              <gl-icon name="remove" class="gl-mr-2" variant="current" aria-hidden="true" />
              {{ __('Delete') }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
  </li>
</template>
