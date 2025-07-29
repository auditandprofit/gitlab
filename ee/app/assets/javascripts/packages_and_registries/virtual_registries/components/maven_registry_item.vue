<script>
import { GlButton, GlLink, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import ListItem from '~/vue_shared/components/registry/list_item.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'MavenVirtualRegistryItem',
  components: {
    GlButton,
    GlLink,
    GlSprintf,
    ListItem,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['editPathTemplate', 'showPathTemplate'],
  props: {
    registry: {
      type: Object,
      required: true,
    },
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    editUrl() {
      return this.editPathTemplate.replace(':id', this.registry.id);
    },
    showUrl() {
      return this.showPathTemplate.replace(':id', this.registry.id);
    },
  },
};
</script>

<template>
  <li class="gl-list-none">
    <list-item>
      <template #left-primary>
        <gl-link :href="showUrl" class="gl-min-w-0 gl-break-all gl-font-bold gl-text-default">
          {{ registry.name }}
        </gl-link>
      </template>
      <template #right-secondary>
        <span>
          <gl-sprintf :message="s__('VirtualRegistry|Updated %{date}')">
            <template #date>
              <time-ago-tooltip :time="registry.updated_at" />
            </template>
          </gl-sprintf>
        </span>
      </template>
      <template #right-action>
        <gl-button
          v-if="canEdit"
          v-gl-tooltip="__('Edit')"
          :aria-label="__('Edit')"
          size="small"
          category="tertiary"
          icon="pencil"
          :href="editUrl"
        />
      </template>
    </list-item>
  </li>
</template>
