<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { sprintf, s__, __ } from '~/locale';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  ACTION_PRIMARY: {
    text: s__('SecurityOrchestration|Remove group'),
    attributes: { variant: 'danger' },
  },
  name: 'UnassignGroupModal',
  components: {
    GlModal,
    GlSprintf,
  },
  props: {
    groupName: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    unassignModalTitle() {
      return sprintf(s__('SecurityOrchestration|Remove %{group}'), {
        group: this.groupName,
      });
    },
  },
  methods: {
    hideModalWindow() {
      this.$refs.modal.hide();
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by parent via $refs to open modal
    showModalWindow() {
      this.$refs.modal.show();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    modal-id="unassign-group-modal"
    :title="unassignModalTitle"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="$options.ACTION_PRIMARY"
    @cancel="hideModalWindow"
    @primary="$emit('unassign')"
  >
    <span class="gl-block">
      {{
        s__(
          'SecurityOrchestration|Selecting this will disconnect your top level compliance and security policy (CSP) group from all the other top level groups. All frameworks shared by the top level CSP group will also be disconnected due to this action.',
        )
      }}
    </span>
    <span class="gl-block gl-pt-5">
      <gl-sprintf
        :message="
          s__('SecurityOrchestration|Are you sure you want to remove %{group} as CSP group?')
        "
      >
        <template #group>
          <strong>{{ groupName }}</strong>
        </template>
      </gl-sprintf>
    </span>
  </gl-modal>
</template>
