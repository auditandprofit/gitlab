<script>
import { GlAlert, GlButton, GlModal, GlSprintf } from '@gitlab/ui';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { s__, __ } from '~/locale';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { updateMavenUpstream, deleteMavenUpstream } from 'ee/api/virtual_registries_api';
import RegistryUpstreamForm from '../components/registry_upstream_form.vue';

export default {
  name: 'MavenEditUpstreamApp',
  components: {
    GlAlert,
    GlButton,
    GlModal,
    GlSprintf,
    PageHeading,
    RegistryUpstreamForm,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    upstream: {
      default: {},
    },
    registriesPath: {
      default: '',
    },
    upstreamPath: {
      default: '',
    },
  },
  data() {
    return {
      alertMessage: '',
      loading: false,
      showDeleteModal: false,
    };
  },
  methods: {
    async updateUpstream(formData) {
      this.alertMessage = '';
      this.loading = true;
      try {
        await updateMavenUpstream({
          id: this.upstream.id,
          data: formData,
        });

        visitUrlWithAlerts(this.upstreamPath, [
          {
            message: s__('VirtualRegistry|Maven upstream has been updated.'),
          },
        ]);
      } catch (e) {
        this.alertMessage = this.parseError(e);
      } finally {
        this.loading = false;
      }
    },
    async deleteUpstream() {
      this.alertMessage = '';
      this.loading = true;
      try {
        await deleteMavenUpstream({
          id: this.upstream.id,
        });

        visitUrlWithAlerts(this.registriesPath, [
          {
            message: s__('VirtualRegistry|Maven upstream has been deleted.'),
          },
        ]);
      } catch (e) {
        this.alertMessage = this.parseError(e);
      } finally {
        this.loading = false;
      }
    },
    parseError(e) {
      return e.response?.data?.error || e.message;
    },
  },
  modal: {
    primaryAction: {
      text: __('Delete'),
      attributes: {
        variant: 'danger',
        category: 'primary',
      },
    },
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('VirtualRegistry|Edit upstream')">
      <template v-if="glAbilities.destroyVirtualRegistry" #actions>
        <gl-button category="tertiary" variant="danger" @click="showDeleteModal = true">
          {{ s__('VirtualRegistry|Delete upstream') }}
        </gl-button>
      </template>
    </page-heading>
    <gl-alert v-if="alertMessage" class="gl-mb-3" variant="danger" :dismissible="false">
      {{ alertMessage }}
    </gl-alert>
    <gl-modal
      v-model="showDeleteModal"
      modal-id="delete-upstream-modal"
      size="sm"
      :action-primary="$options.modal.primaryAction"
      :action-cancel="$options.modal.cancelAction"
      :title="s__('VirtualRegistry|Delete Maven upstream')"
      @primary="deleteUpstream"
      @cancel="showDeleteModal = false"
    >
      <gl-sprintf :message="s__('VirtualRegistry|Are you sure you want to delete %{name}?')">
        <template #name>
          <strong>{{ upstream.name }}</strong>
        </template>
      </gl-sprintf>
    </gl-modal>
    <registry-upstream-form
      :upstream="upstream"
      :loading="loading"
      class="gl-w-9/12"
      @submit="updateUpstream"
    />
  </div>
</template>
