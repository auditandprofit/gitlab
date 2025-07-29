<script>
import {
  GlFormCheckbox,
  GlFormGroup,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { DOCS_URL } from 'jh_else_ce/lib/utils/url_utility';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'DuoCoreFeaturesForm',
  i18n: {
    sectionTitle: __('Gitlab Duo Core'),
    subtitle: s__(
      'AiPowered|When turned on, all billable users can access GitLab Duo Chat and Code Suggestions in supported IDEs.',
    ),
    checkboxLabel: s__('AiPowered|Turn on IDE features'),
    checkboxHelpTextSaaS: s__(
      'AiPowered|This setting applies to the whole top-level group. By turning this on, you accept the %{termsLinkStart}GitLab AI Functionality Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab governing AI feature usage. Check the %{requirementsLinkStart}eligibility requirements%{requirementsLinkEnd}.',
    ),
    checkboxHelpTextSelfManaged: s__(
      'AiPowered|This setting applies to the whole instance. By turning this on, you accept the %{termsLinkStart}GitLab AI Functionality Terms%{termsLinkEnd} unless your organization has a separate agreement with GitLab governing AI feature usage. Check the %{requirementsLinkStart}eligibility requirements%{requirementsLinkEnd}.',
    ),
  },
  components: {
    GlFormCheckbox,
    GlFormGroup,
    GlIcon,
    GlLink,
    GlSprintf,
    PromoPageLink,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['isSaaS'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
    };
  },
  computed: {
    description() {
      return this.isSaaS
        ? this.$options.i18n.checkboxHelpTextSaaS
        : this.$options.i18n.checkboxHelpTextSelfManaged;
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.duoCoreEnabled);
    },
  },
  requirementsPath: `${DOCS_URL}/subscriptions/subscription-add-ons#gitlab-duo-core`,
  termsPath: `/handbook/legal/ai-functionality-terms/`,
};
</script>
<template>
  <div>
    <gl-form-group
      :label="$options.i18n.sectionTitle"
      :label-description="$options.i18n.subtitle"
      class="gl-my-4"
    >
      <gl-form-checkbox
        v-model="duoCoreEnabled"
        data-testid="use-duo-core-features-checkbox"
        :disabled="disabledCheckbox"
        @change="checkboxChanged"
      >
        <div class="gl-flex">
          <span id="duo-core-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
          <button
            v-if="disabledCheckbox"
            v-tooltip="
              s__(
                'AiPowered|This setting requires GitLab Duo availability to be on or off by default.',
              )
            "
            type="button"
            class="gl-ml-2 gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0"
            :aria-label="s__('AiPowered|Lock tooltip icon')"
            variant="subtle"
          >
            <gl-icon name="lock" />
          </button>
        </div>
        <template #help>
          <gl-sprintf :message="description">
            <template #br>
              <br />
            </template>
            <template #termsLink="{ content }">
              <promo-page-link :path="$options.termsPath" target="_blank">{{
                content
              }}</promo-page-link>
            </template>
            <template #requirementsLink="{ content }">
              <gl-link :href="$options.requirementsPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
