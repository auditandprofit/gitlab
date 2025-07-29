<script>
import { GlCollapsibleListbox, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { DEFAULT_TEMPLATE, LATEST_TEMPLATE } from './constants';

export default {
  i18n: {
    label: s__('SecurityOrchestration|Security job template'),
    defaultTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The default template is stable, but may not have all the features of the latest template.',
    ),
    latestTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The latest edition may introduce breaking changes.',
    ),
  },
  components: {
    GlCollapsibleListbox,
    HelpIcon,
    SectionLayout,
  },
  directives: {
    GlTooltip,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: DEFAULT_TEMPLATE,
    },
  },
  computed: {
    availableOptions() {
      return [
        { text: s__('SecurityOrchestration|latest'), value: LATEST_TEMPLATE },
        { text: s__('SecurityOrchestration|default'), value: DEFAULT_TEMPLATE },
      ];
    },
    tooltipMessage() {
      return this.selected === LATEST_TEMPLATE
        ? this.$options.i18n.latestTemplateInformation
        : this.$options.i18n.defaultTemplateInformation;
    },
  },
  methods: {
    toggleValue(value) {
      if (value === LATEST_TEMPLATE) {
        this.$emit('input', { template: value });
      } else {
        this.$emit('remove');
      }
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-default"
    content-classes="gl-justify-between"
    :show-remove-button="false"
  >
    <template #selector>
      <label class="gl-mb-0 gl-mr-4" for="policy-template" :title="$options.i18n.label">
        {{ $options.i18n.label }}
      </label>
    </template>

    <template #content>
      <div class="gl-flex gl-grow-2 gl-items-center">
        <gl-collapsible-listbox
          id="policy-template"
          :items="availableOptions"
          :selected="selected"
          @select="toggleValue"
        />
        <help-icon v-gl-tooltip :title="tooltipMessage" class="gl-ml-3" />
      </div>
    </template>
  </section-layout>
</template>
