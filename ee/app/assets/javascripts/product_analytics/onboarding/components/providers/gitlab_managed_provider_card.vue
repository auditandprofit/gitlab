<script>
import { GlButton, GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import CloudTanukiIllustrationPath from '@gitlab/svgs/dist/illustrations/cloud-tanuki-sm.svg';

import { PROMO_URL } from '~/constants';
import { s__ } from '~/locale';

import ClearProjectSettingsModal from './clear_project_settings_modal.vue';
import { projectSettingsValidator } from './utils';

export default {
  name: 'GitlabManagedProviderCard',
  components: { ClearProjectSettingsModal, GlButton, GlFormCheckbox, GlSprintf },
  inject: {
    managedClusterPurchased: {
      default: false,
    },
  },
  props: {
    projectSettings: {
      type: Object,
      required: true,
      validator: projectSettingsValidator,
    },
  },
  data() {
    return {
      hasAgreedToGCPZone: false,
      gcpZoneError: null,
      clearSettingsModalIsVisible: false,
    };
  },
  computed: {
    hasAnyProjectLevelProviderConfig() {
      return Object.values(this.projectSettings).some(Boolean);
    },
  },
  methods: {
    async onSelected() {
      if (!this.ensureAgreedToGcpZone()) {
        return;
      }

      if (this.hasAnyProjectLevelProviderConfig) {
        this.clearSettingsModalIsVisible = true;
        return;
      }

      this.$emit('confirm', CloudTanukiIllustrationPath);
    },
    ensureAgreedToGcpZone() {
      if (this.hasAgreedToGCPZone) {
        this.gcpZoneError = null;
        return true;
      }

      this.gcpZoneError = s__(
        'ProductAnalytics|To continue, you must agree to event storage and processing in this region.',
      );
      return false;
    },
  },
  zone: 'us-central-1',
  contactSalesUrl: `${PROMO_URL}/sales/`,
  CloudTanukiIllustrationPath,
};
</script>
<template>
  <div class="gl-flex gl-w-full gl-gap-6 gl-rounded-base gl-border-solid gl-border-default gl-p-6">
    <div class="gl-hidden gl-shrink-0 md:gl-block">
      <img class="gl-dark-invert-keep-hue" :src="$options.CloudTanukiIllustrationPath" :alt="''" />
    </div>
    <div class="gl-flex gl-w-full gl-grow gl-flex-col">
      <h3 class="gl-mt-0">
        {{ s__('ProductAnalytics|GitLab-managed provider') }}
      </h3>
      <p class="gl-mb-6">
        {{
          s__(
            'ProductAnalytics|Use a GitLab-managed infrastructure to process, store, and query analytics events data.',
          )
        }}
      </p>
      <h4 class="gl-mt-0 gl-text-lg">{{ s__('ProductAnalytics|For this option:') }}</h4>
      <ul class="gl-mb-6">
        <li>
          <gl-sprintf
            :message="
              s__(
                'ProductAnalytics|The Product Analytics Beta on GitLab.com is offered only in the Google Cloud Platform zone %{zone}.',
              )
            "
          >
            <template #zone>
              <code class="gl-whitespace-nowrap">{{ $options.zone }}</code>
            </template>
          </gl-sprintf>
        </li>
      </ul>
      <template v-if="managedClusterPurchased">
        <div class="gl-mb-6 gl-mt-auto">
          <gl-form-checkbox v-model="hasAgreedToGCPZone" data-testid="region-agreement-checkbox">{{
            s__('ProductAnalytics|I agree to event collection and processing in this region.')
          }}</gl-form-checkbox>
          <div v-if="gcpZoneError" class="gl-text-danger" data-testid="gcp-zone-error">
            {{ gcpZoneError }}
          </div>
        </div>
        <gl-button
          category="primary"
          variant="confirm"
          class="gl-self-start"
          data-testid="connect-gitlab-managed-provider-btn"
          @click="onSelected"
          >{{ s__('ProductAnalytics|Use GitLab-managed provider') }}</gl-button
        >
      </template>
      <gl-button
        v-else
        category="primary"
        variant="confirm"
        class="gl-self-start"
        data-testid="contact-sales-team-btn"
        :href="$options.contactSalesUrl"
        >{{ s__('ProductAnalytics|Contact our sales team') }}</gl-button
      >
    </div>
    <clear-project-settings-modal
      :visible="clearSettingsModalIsVisible"
      @hide="clearSettingsModalIsVisible = false"
      @cleared="onSelected"
    >
      {{
        s__(
          `ProductAnalytics|This project has analytics provider settings configured. If you continue, the settings for projects will be reset so that GitLab-managed provider settings can be used.`,
        )
      }}
    </clear-project-settings-modal>
  </div>
</template>
