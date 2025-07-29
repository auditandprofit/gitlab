<script>
import { GlBadge, GlIcon, GlDisclosureDropdown, GlTruncate } from '@gitlab/ui';
import { SAST_FINDING_DISMISSED } from '~/diffs/constants';
import { firstSentenceOfText } from './inline_findings_dropdown_utils';

export default {
  components: {
    GlIcon,
    GlBadge,
    GlDisclosureDropdown,
    GlTruncate,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    iconId: {
      type: String,
      required: false,
      default: '',
    },
    iconKey: {
      type: String,
      required: false,
      default: '',
    },
    iconName: {
      type: String,
      required: false,
      default: '',
    },
    iconClass: {
      type: String,
      required: false,
      default: '',
    },
  },
  methods: {
    firstSentence(text) {
      return firstSentenceOfText(text);
    },
    emitMouseEnter() {
      this.$emit('mouseenter');
    },
    emitMouseLeave() {
      this.$emit('mouseleave');
    },
    findingsStatus(item) {
      return item.state === SAST_FINDING_DISMISSED;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    :items="items"
    :fluid-width="true"
    positioning-strategy="absolute"
    class="findings-dropdown gl-whitespace-normal !gl-text-default"
  >
    <template #group-label="{ group }">
      {{ group.name }}
    </template>

    <template #list-item="{ item }">
      <span class="gl-flex gl-items-center gl-text-subtle">
        <gl-icon
          :size="12"
          :name="item.name"
          :class="item.class"
          class="inline-findings-severity-icon gl-mr-4"
        />
        <span class="findings-dropdown-width gl-flex gl-truncate !gl-whitespace-nowrap"
          ><span class="gl-self-center gl-font-bold gl-capitalize gl-text-default"
            >{{ item.severity }}: </span
          ><gl-truncate
            class="findings-dropdown-truncate gl-self-center"
            :text="firstSentence(item.text)"
          />
          <gl-badge v-if="findingsStatus(item)" variant="neutral" class="gl-ml-3 gl-capitalize">{{
            item.state
          }}</gl-badge>
        </span>
      </span>
    </template>
    <template #toggle>
      <gl-icon
        :id="iconId"
        ref="firstInlineFindingsIcon"
        :key="iconKey"
        :name="iconName"
        :class="iconClass"
        data-testid="toggle-icon"
        class="inline-findings-severity-icon gl-relative gl-top-1 !gl-align-baseline hover:gl-cursor-pointer"
        @mouseenter="emitMouseEnter"
        @mouseleave="emitMouseLeave"
      />
    </template>
  </gl-disclosure-dropdown>
</template>
