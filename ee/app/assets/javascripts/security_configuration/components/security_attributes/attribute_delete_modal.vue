<script>
import { GlModal } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';

const i18ns = {
  title: s__('SecurityAttributes|Delete security attribute?'),
  cancelButton: __('Cancel'),
  deleteButton: s__('SecurityAttributes|Delete security attribute'),
  deleteMessageTemplate: s__(
    'SecurityAttributes|Deleting the "%{attributeName}" Security Attribute will permanently remove it from its category and any projects where it is applied. This action cannot be undone.',
  ),
};

export default {
  components: {
    GlModal,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    attribute: {
      type: Object,
      required: true,
    },
  },
  computed: {
    deleteMessage() {
      return sprintf(i18ns.deleteMessageTemplate, {
        attributeName: this.attribute.name,
      });
    },
  },
  methods: {
    onConfirm() {
      this.$emit('confirm');
    },
    onCancel() {
      this.$emit('cancel');
    },
  },
  i18ns,
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="delete-security-attribute-modal"
    :title="$options.i18ns.title"
    :ok-title="$options.i18ns.deleteButton"
    :cancel-title="$options.i18ns.cancelButton"
    ok-variant="danger"
    @hide="onCancel"
    @ok="onConfirm"
  >
    <p>
      {{ deleteMessage }}
    </p>
  </gl-modal>
</template>
