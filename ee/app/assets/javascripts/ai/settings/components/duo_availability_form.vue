<script>
import { GlSprintf, GlFormRadioGroup, GlFormRadio, GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from '../constants';

const IS_SAAS_ATTRIBUTE = true;
const IS_SELF_MANAGED_ATTRIBUTE = false;

export default {
  name: 'DuoAvailabilityForm',
  availabilityOptions: {
    defaultOn: AVAILABILITY_OPTIONS.DEFAULT_ON,
    defaultOff: AVAILABILITY_OPTIONS.DEFAULT_OFF,
    alwaysOff: AVAILABILITY_OPTIONS.NEVER_ON,
  },
  i18n: {
    subtitle: {
      [IS_SAAS_ATTRIBUTE]: s__(
        'AiPowered|Control whether GitLab can process your code and project data to provide context to AI-powered features.',
      ),
      [IS_SELF_MANAGED_ATTRIBUTE]: s__(
        'AiPowered|Control whether AI-powered features are available.',
      ),
    },
    defaultOnText: s__('AiPowered|On by default'),
    defaultOnHelpText: {
      [IS_SAAS_ATTRIBUTE]: s__(
        'AiPowered|Allow GitLab to process your code and project data for AI-powered features throughout this namespace. Your data will be sent to GitLab Duo for processing. Groups, subgroups, and projects can individually opt out if needed.',
      ),
      [IS_SELF_MANAGED_ATTRIBUTE]: s__(
        'AiPowered|Features are available. However, any group, subgroup, or project can turn them off.',
      ),
    },
    defaultOffText: s__('AiPowered|Off by default'),
    defaultOffHelpText: {
      [IS_SAAS_ATTRIBUTE]: s__(
        'AiPowered|Block GitLab from processing your code and project data for AI-powered features by default. Your data stays private unless subgroups or projects individually opt in.',
      ),
      [IS_SELF_MANAGED_ATTRIBUTE]: s__(
        'AiPowered|Features are not available. However, any group, subgroup, or project can turn them on.',
      ),
    },
    alwaysOffText: s__('AiPowered|Always off'),
    alwaysOffHelpText: {
      [IS_SAAS_ATTRIBUTE]: s__(
        'AiPowered|Never allow GitLab to process your code and project data for AI-powered features. Your data will not be sent to GitLab Duo anywhere in this namespace.',
      ),
      [IS_SELF_MANAGED_ATTRIBUTE]: s__(
        'AiPowered|Features are not available and cannot be turned on for any group, subgroup, or project.',
      ),
    },
  },
  components: {
    GlSprintf,
    GlFormRadioGroup,
    GlFormRadio,
    GlFormGroup,
    CascadingLockIcon,
  },
  inject: ['isSaaS', 'areDuoSettingsLocked', 'cascadingSettingsData'],
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      duoAvailabilityState: this.duoAvailability,
    };
  },
  computed: {
    showCascadingButton() {
      return (
        this.areDuoSettingsLocked &&
        this.cascadingSettingsData &&
        Object.keys(this.cascadingSettingsData).length
      );
    },
  },
  methods: {
    radioChanged() {
      this.$emit('change', this.duoAvailabilityState);
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group
      :label="s__('AiPowered|GitLab Duo availability')"
      :label-description="$options.i18n.subtitle[isSaaS]"
    >
      <gl-form-radio-group v-model="duoAvailabilityState">
        <gl-form-radio
          :value="$options.availabilityOptions.defaultOn"
          :disabled="areDuoSettingsLocked"
          @change="radioChanged"
        >
          {{ $options.i18n.defaultOnText }}

          <template #help>
            <gl-sprintf :message="$options.i18n.defaultOnHelpText[isSaaS]" />
          </template>
        </gl-form-radio>

        <slot name="amazon-q-settings"></slot>

        <gl-form-radio
          :value="$options.availabilityOptions.defaultOff"
          :disabled="areDuoSettingsLocked"
          @change="radioChanged"
        >
          {{ $options.i18n.defaultOffText }}
          <template #help>
            <gl-sprintf :message="$options.i18n.defaultOffHelpText[isSaaS]" />
          </template>
        </gl-form-radio>

        <gl-form-radio
          :value="$options.availabilityOptions.alwaysOff"
          :disabled="areDuoSettingsLocked"
          @change="radioChanged"
        >
          {{ $options.i18n.alwaysOffText }}
          <cascading-lock-icon
            v-if="showCascadingButton"
            :is-locked-by-group-ancestor="cascadingSettingsData.lockedByAncestor"
            :is-locked-by-application-settings="cascadingSettingsData.lockedByApplicationSetting"
            :ancestor-namespace="cascadingSettingsData.ancestorNamespace"
            class="gl-ml-1"
          />
          <template #help>
            <gl-sprintf :message="$options.i18n.alwaysOffHelpText[isSaaS]" />
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>
  </div>
</template>
