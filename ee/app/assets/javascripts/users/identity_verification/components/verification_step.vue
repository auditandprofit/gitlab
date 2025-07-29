<script>
import { GlCard, GlBadge, GlIcon } from '@gitlab/ui';
import GitlabExperiment from '~/experimentation/components/gitlab_experiment.vue';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'VerificationStep',
  components: {
    GlCard,
    GlBadge,
    GitlabExperiment,
    GlIcon,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    completed: {
      type: Boolean,
      required: true,
    },
    isActive: {
      type: Boolean,
      required: true,
    },
    totalSteps: {
      type: Number,
      required: false,
      default: 0,
    },
    stepIndex: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    cardBodyClasses() {
      // Remove padding but add gl-pb-1 so body has the minimum height to retain
      // rounded bottom corners
      return { 'gl-p-0 gl-pb-1': !this.isActive };
    },
    titleClasses() {
      const borderClasses = 'gl-pb-5 gl-border-1 gl-border-b-solid gl-border-default';
      const defaultClasses = 'gl-text-base gl-my-2 gl-flex gl-justify-between';
      return { [borderClasses]: this.isActive, [defaultClasses]: true };
    },
    titleClassesLWRExperiment() {
      const defaultClasses = 'gl-bg-subtle gl-p-0 gl-pt-6 border-bottom-0';
      const borderClasses = 'gl-border-strong gl-border-1 gl-border-t';

      const applyBorder = this.stepIndex !== 0;

      return {
        [defaultClasses]: true,
        [borderClasses]: applyBorder,
      };
    },
    stepHelpText() {
      if (this.totalSteps > 1) {
        return sprintf(s__('IdentityVerification|Step %{stepIndex} of %{totalSteps}'), {
          stepIndex: this.stepIndex + 1,
          totalSteps: this.totalSteps,
        });
      }
      return '';
    },
    cardClasses() {
      return { 'gl-mt-6': this.stepIndex !== 0 };
    },
  },
  i18n: {
    completed: __('Completed'),
  },
};
</script>
<template>
  <gitlab-experiment name="lightweight_trial_registration_redesign">
    <template #control>
      <gl-card class="gl-mb-3" header-class="gl-border-b-0" :body-class="cardBodyClasses">
        <template #header>
          <h3 :class="titleClasses">
            {{ title }}
            <gl-badge v-if="completed" variant="success" icon="check-circle-filled" icon-size="sm">
              {{ $options.i18n.completed }}
            </gl-badge>
          </h3>
        </template>
        <template #default>
          <slot v-if="isActive"></slot>
        </template>
      </gl-card>
    </template>

    <template #candidate>
      <gl-card
        :header-class="titleClassesLWRExperiment"
        class="gl-border-none"
        :class="cardClasses"
        body-class="gl-p-0"
      >
        <template #header>
          <div class="gl-flex gl-justify-between">
            <h3 class="gl-m-0 gl-text-lg">{{ title }}</h3>
            <span v-if="completed" class="gl-text-secondary">
              <gl-icon name="check" :size="16" />
              <span>{{ $options.i18n.completed }}</span>
            </span>
            <span v-else class="gl-text-secondary">{{ stepHelpText }}</span>
          </div>
        </template>
        <template #default>
          <slot v-if="isActive"></slot>
        </template>
      </gl-card>
    </template>
  </gitlab-experiment>
</template>
