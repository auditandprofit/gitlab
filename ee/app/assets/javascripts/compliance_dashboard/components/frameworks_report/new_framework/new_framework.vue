<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import PROJECT_CREATE_NEW_SVG_URL from '@gitlab/svgs/dist/illustrations/project-create-new-sm.svg?url';
import PROJECT_IMPORT_SVG_URL from '@gitlab/svgs/dist/illustrations/project-import-sm.svg?url';
import { createAlert, VARIANT_DANGER, VARIANT_SUCCESS } from '~/alert';
import Tracking from '~/tracking';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import { ROUTE_BLANK_FRAMEWORK, ROUTE_EDIT_FRAMEWORK } from '../../../constants';

export default {
  components: {
    GlSprintf,
    GlLink,
  },
  mixins: [Tracking.mixin()],
  inject: ['frameworkImportUrl'],
  data() {
    return {
      panels: [
        {
          name: 'blank_framework',
          title: s__('ComplianceFramework|Create blank framework'),
          description: s__(
            'ComplianceFramework|Create a new compliance framework from scratch to define your compliance requirements.',
          ),
          imageSrc: PROJECT_CREATE_NEW_SVG_URL,
          onClick: this.navigatetoNewFramework,
        },
        {
          name: 'import_framework',
          title: s__('ComplianceFramework|Import framework'),
          description: s__(
            'ComplianceFramework|Import an existing compliance framework from a JSON file.',
          ),
          imageSrc: PROJECT_IMPORT_SVG_URL,
          onClick: this.handleFrameworkImport,
        },
      ],
    };
  },
  methods: {
    navigatetoNewFramework(event) {
      event.preventDefault();
      this.track('click_tab', { label: 'blank_framework' });
      this.$router.push({ name: ROUTE_BLANK_FRAMEWORK });
    },
    handleFrameworkImport(event) {
      event.preventDefault();
      this.track('click_tab', { label: 'import_framework' });
      this.$refs.fileInput.click();
    },
    async handleFileUpload(event) {
      const file = event.target.files[0];
      if (!file) return;
      if (!this.frameworkImportUrl) {
        createAlert({
          message: s__(
            'ComplianceFramework|Unable to determine the correct upload URL. Please try again.',
          ),
          variant: VARIANT_DANGER,
        });
        return;
      }

      const formData = new FormData();
      formData.append('framework_file', file);

      try {
        const response = await axios.post(this.frameworkImportUrl, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        });

        if (!response.data.framework_id) return;

        if (response.data.message) {
          createAlert({
            message: response.data.message,
            variant: VARIANT_DANGER,
          });
        } else {
          createAlert({
            message: s__('ComplianceFramework|Framework imported successfully.'),
            variant: VARIANT_SUCCESS,
          });
        }

        this.$router.push({
          name: ROUTE_EDIT_FRAMEWORK,
          params: { id: response.data.framework_id },
        });
      } catch (error) {
        let errorMessage = s__('ComplianceFramework|Failed to import framework file.');

        if (error.response?.data?.message) {
          errorMessage = error.response.data.message;
        } else if (error.message) {
          errorMessage += ` ${error.message}`;
        }

        createAlert({
          message: errorMessage,
          variant: VARIANT_DANGER,
        });
      }
    },
  },
  complianceAdherenceTemplatesLink:
    'https://gitlab.com/gitlab-org/software-supply-chain-security/compliance/engineering/compliance-adherence-templates',
};
</script>

<template>
  <div>
    <div class="gl-flex gl-flex-col">
      <h2 class="gl-my-7 gl-text-center gl-text-size-h1" data-testid="new-framework-page-title">
        {{ s__('ComplianceFramework|Create new framework') }}
      </h2>
      <section class="gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
        <a
          v-for="panel in panels"
          :key="panel.name"
          :data-testid="`new-framework-${panel.name}`"
          class="gl-flex gl-cursor-pointer gl-flex-col gl-items-center gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-px-3 gl-py-6 hover:!gl-no-underline md:gl-w-1/2 lg:gl-flex-row"
          @click="panel.onClick"
        >
          <div class="gl-flex gl-shrink-0 gl-justify-center">
            <img aria-hidden="true" :src="panel.imageSrc" :alt="panel.title" />
          </div>
          <div class="gl-pl-4">
            <h3 class="gl-text-color-heading gl-text-size-h2">
              {{ panel.title }}
            </h3>
            <p class="gl-text-default">
              {{ panel.description }}
            </p>
          </div>
        </a>
      </section>
      <p class="gl-pt-5 gl-text-center">
        <gl-sprintf
          :message="
            s__(
              'ComplianceFramework|Looking for a template? Need an example JSON schema? Look through our %{linkStart}examples here.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link
              :href="$options.complianceAdherenceTemplatesLink"
              target="_blank"
              data-testid="compliance-adherence-templates-link"
            >
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
      <input
        ref="fileInput"
        class="gl-hidden"
        type="file"
        accept=".json"
        data-testid="new-framework-file-input"
        @change="handleFileUpload"
      />
    </div>
  </div>
</template>
