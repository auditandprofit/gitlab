<script>
import { GlButton, GlModal, GlSprintf, GlModalDirective } from '@gitlab/ui';
import { sprintf } from '~/locale';

export default {
  components: {
    GlButton,
    GlModal,
    GlSprintf,
  },
  directives: {
    GlModalDirective,
  },
  inject: {
    itemTitle: {
      type: String,
    },
  },
  props: {
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      modalAction: null,
    };
  },
  computed: {
    modalTitle() {
      if (!this.modalAction) {
        return null;
      }

      return sprintf(this.modalAction.modal.title, {
        type: this.itemTitle,
      });
    },
    modalDescription() {
      return sprintf(this.modalAction.modal.description, {
        type: this.itemTitle,
      });
    },
  },
  methods: {
    setModalData(action) {
      this.modalAction = action;
    },
  },
  GEO_BULK_ACTION_MODAL_ID: 'geo-bulk-action',
};
</script>

<template>
  <div>
    <div>
      <gl-button
        v-for="action in bulkActions"
        :key="action.id"
        v-gl-modal-directive="$options.GEO_BULK_ACTION_MODAL_ID"
        :data-testid="action.id"
        class="gl-ml-2"
        @click="setModalData(action)"
      >
        {{ action.text }}
      </gl-button>
    </div>
    <gl-modal
      :modal-id="$options.GEO_BULK_ACTION_MODAL_ID"
      :title="modalTitle"
      size="sm"
      @primary="$emit('bulkAction', modalAction.action)"
    >
      <gl-sprintf v-if="modalAction" :message="modalDescription">
        <template #type>{{ itemTitle }}</template>
      </gl-sprintf>
    </gl-modal>
  </div>
</template>
