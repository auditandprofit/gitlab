<script>
import { GlButton, GlSprintf, GlModal, GlModalDirective } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { __, s__ } from '~/locale';

export default {
  components: {
    GlButton,
    GlSprintf,
    GlModal,
    CrudComponent,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  inject: ['projectPath'],
  props: {
    agentVersion: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    modalTitle: s__('AIAgent|Delete agent?'),
    sectionTitle: s__('AIAgent|Delete this agent'),
    sectionBody: s__(
      'AIAgent|This action permanently deletes the %{codeStart}%{agentName}%{codeEnd} AI Agent.',
    ),
    deleteAgent: s__('AIAgent|Delete Agent'),
    deleteAgentConfirmation: s__(
      'AIAgent|AI Agent %{codeStart}%{agentName}%{codeEnd} will be permanently deleted. Are you sure?',
    ),
    cancel: __('Cancel'),
  },
  data() {
    return {
      deleteProps: {
        text: this.$options.i18n.deleteAgent,
        attributes: { category: 'primary', variant: 'danger' },
      },
      cancelProps: {
        text: this.$options.i18n.cancel,
      },
    };
  },
  deleteModalId: 'deleteModalId',
  methods: {
    onSubmitDeleteModal() {
      this.$emit('destroy', {
        projectPath: this.projectPath,
        agentId: this.agentVersion.id,
      });
    },
  },
};
</script>

<template>
  <crud-component
    :title="$options.i18n.sectionTitle"
    title-class="gl-text-danger"
    body-class="gl-bg-red-50 !gl-m-0 gl-px-5 gl-py-4"
  >
    <p>
      <gl-sprintf :message="$options.i18n.sectionBody">
        <template #code>
          <code>{{ agentVersion.name }}</code>
        </template>
      </gl-sprintf>
    </p>

    <gl-button
      v-gl-modal="$options.deleteModalId"
      variant="danger"
      class="gl-mt-3 gl-block"
      :loading="loading"
      >{{ $options.i18n.deleteAgent }}</gl-button
    >
    <gl-modal
      :ref="$options.deleteModalId"
      :modal-id="$options.deleteModalId"
      :title="$options.i18n.modalTitle"
      :action-primary="deleteProps"
      :action-cancel="cancelProps"
      @primary="onSubmitDeleteModal"
    >
      <gl-sprintf :message="$options.i18n.deleteAgentConfirmation">
        <template #code>
          <code>{{ agentVersion.name }}</code>
        </template>
      </gl-sprintf>
    </gl-modal>
  </crud-component>
</template>
