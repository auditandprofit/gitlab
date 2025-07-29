<script>
import { GlButton, GlDrawer, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

export default {
  name: 'AiCatalogItemDrawer',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlDrawer,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
    activeItem: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    editRoute: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    getDrawerHeight() {
      return `calc(${getContentWrapperHeight()} + var(--top-bar-height))`;
    },
    activeItemId() {
      return this.activeItem ? getIdFromGraphQLId(this.activeItem.id) : '';
    },
  },
  DRAWER_Z_INDEX,
};
</script>
<template>
  <gl-drawer
    :open="isOpen"
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="getDrawerHeight"
    header-sticky
    class="gl-w-full gl-leading-reset lg:gl-w-[480px] xl:gl-w-[768px] min-[1440px]:gl-w-[912px]"
    @close="$emit('close')"
  >
    <template #title>
      <div class="gl-text gl-flex gl-w-full gl-items-center gl-gap-x-4 xl:gl-px-4">
        <h2 class="gl-m-0">
          {{ activeItem.name }}
        </h2>
        <gl-button
          v-if="editRoute"
          v-gl-tooltip
          :to="{ name: editRoute, params: { id: activeItemId } }"
          :title="s__('AICatalog|Edit')"
          category="tertiary"
          icon="pencil"
          size="small"
          :aria-label="s__('AICatalog|Edit')"
        />
      </div>
    </template>
    <template #default>
      <div class="xl:!gl-px-6">
        <div>
          <p>
            {{ activeItem.description }}
          </p>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
