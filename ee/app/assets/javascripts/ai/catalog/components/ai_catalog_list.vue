<script>
import { GlEmptyState, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import AiCatalogListItem from './ai_catalog_list_item.vue';

export default {
  name: 'AiCatalogList',
  components: {
    AiCatalogListItem,
    ConfirmActionModal,
    GlEmptyState,
    GlSkeletonLoader,
    GlSprintf,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    deleteConfirmTitle: {
      type: String,
      required: false,
      default: '',
    },
    deleteConfirmMessage: {
      type: String,
      required: false,
      default: '',
    },
    deleteFn: {
      type: Function,
      required: false,
      default: () => {},
    },
  },
  data() {
    return {
      itemToDelete: null,
    };
  },
  methods: {
    async deleteItem() {
      await this.deleteFn(this.itemToDelete.id);

      this.itemToDelete = null;
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div data-testid="ai-catalog-list">
    <gl-skeleton-loader v-if="isLoading" :lines="2" />

    <template v-else-if="items.length > 0">
      <ul class="gl-list-style-none gl-m-0 gl-p-0">
        <ai-catalog-list-item
          v-for="item in items"
          :key="item.id"
          :item="item"
          @delete="itemToDelete = item"
          @select-item="$emit('select-item', item)"
        />
      </ul>

      <confirm-action-modal
        v-if="itemToDelete"
        modal-id="delete-item-modal"
        variant="danger"
        :title="deleteConfirmTitle"
        :action-fn="deleteItem"
        :action-text="__('Delete')"
        @close="itemToDelete = null"
      >
        <gl-sprintf :message="deleteConfirmMessage">
          <template #name>
            <strong>{{ itemToDelete.name }}</strong>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <gl-empty-state
      v-else
      :title="s__('AICatalog|Get started with the AI Catalog')"
      :description="
        s__('AICatalog|Build AI agents and flows to automate repetitive tasks and processes.')
      "
      :svg-path="$options.EMPTY_SVG_URL"
    />
  </div>
</template>
