<script>
import {
  GlAvatar,
  GlAvatarLink,
  GlLink,
  GlTableLite,
  GlTooltipDirective as GlTooltip,
  GlFormRadio,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { ACCESS_LEVEL_DISPLAY } from 'ee/deployments/constants';

export default {
  name: 'MultipleApprovalRulesTable',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlLink,
    GlTableLite,
    GlFormRadio,
  },
  directives: {
    GlTooltip,
  },
  props: {
    rules: {
      required: true,
      type: Array,
    },
  },
  fields: [
    { key: 'approvers', label: s__('DeploymentApprovals|Approvers') },
    { key: 'approvals', label: s__('DeploymentApprovals|Approvals') },
    { key: 'approvedBy', label: s__('DeploymentApprovals|Approved By') },
    { key: 'giveApproval', label: s__('DeploymentApprovals|Give approval') },
  ],
  data() {
    return { selected: null };
  },
  computed: {
    items() {
      return this.rules.map((rule) => ({
        approvers: this.getRuleData(rule),
        approvals: `${rule.approvedCount}/${rule.requiredApprovals}`,
        approvedBy: rule.approvals,
        giveApproval: {
          canApprove: rule.canApprove,
          ruleName: this.getRuleName(rule),
        },
      }));
    },
    currentUserApproved() {
      return Boolean(this.rules.find((rule) => this.hasApproval(rule)));
    },
  },
  mounted() {
    if (!this.selected) {
      const firstRuleToApprove = this.rules.find((rule) => rule.canApprove);
      this.selected = this.getRuleName(firstRuleToApprove);

      this.onChange(this.selected);
    }
  },
  methods: {
    getRuleData(rule) {
      if (rule.group) {
        return { name: rule.group.name, link: rule.group.webUrl };
      }
      if (rule.user) {
        return { name: rule.user.name, link: rule.user.webUrl };
      }

      return { name: ACCESS_LEVEL_DISPLAY[rule.accessLevel.stringValue] };
    },
    getRuleName(rule) {
      return this.getRuleData(rule).name;
    },
    hasApproval(rule) {
      const result = Boolean(
        rule.approvals.find(({ user }) => user.username === gon.current_username),
      );
      if (result) {
        this.selected = this.getRuleName(rule);
      }
      return result;
    },
    onChange($event) {
      this.$emit('select-rule', $event);
    },
  },
};
</script>
<template>
  <gl-table-lite stacked="lg" :fields="$options.fields" :items="items">
    <template #cell(approvers)="{ value }">
      <gl-link v-if="value.link" :href="value.link">{{ value.name }}</gl-link>
      <span v-else>{{ value.name }}</span>
    </template>
    <template #cell(approvedBy)="{ value }">
      <gl-avatar-link
        v-for="approval in value"
        :key="approval.user.id"
        v-gl-tooltip
        :href="approval.user.webUrl"
        :title="approval.user.name"
      >
        <gl-avatar :src="approval.user.avatarUrl" :size="24" aria-hidden="true" />
      </gl-avatar-link>
    </template>
    <template #cell(giveApproval)="{ value }">
      <gl-form-radio
        v-if="value.canApprove"
        v-model="selected"
        :value="value.ruleName"
        :disabled="currentUserApproved"
        @input="onChange"
        >{{ s__('DeploymentApprovals|Approve') }}</gl-form-radio
      >
    </template>
  </gl-table-lite>
</template>
