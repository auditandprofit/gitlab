<script>
import {
  GlButton,
  GlButtonGroup,
  GlBadge,
  GlLink,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { s__, sprintf, n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';

export default {
  name: 'RegistryUpstreamItem',
  components: {
    GlButton,
    GlButtonGroup,
    GlBadge,
    GlLink,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['editUpstreamPathTemplate', 'showUpstreamPathTemplate'],
  props: {
    upstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    upstreamsCount: {
      type: Number,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
  },
  /**
   * Emitted when an upstream is reordered
   * @event reorderUpstream
   * @property {string} direction - The direction to move the upstream ('up' or 'down')
   * @property {string} upstreamId - The ID of the upstream to reorder
   */
  /**
   * Emitted when the cache is cleared
   * @event clearCache
   * @property {string} upstreamId - The ID of the upstream to clear the cache
   */
  /**
   * Emitted when the upstream is deleted
   * @event deleteUpstream
   * @property {string} upstreamId - The ID of the upstream to delete
   */
  emits: ['reorderUpstream', 'clearCache', 'deleteUpstream'],
  computed: {
    name() {
      return this.upstream.name;
    },
    url() {
      return this.upstream.url;
    },
    id() {
      return this.upstream.id;
    },
    idFromGraphQL() {
      return getIdFromGraphQLId(this.upstream.id);
    },
    cacheSize() {
      return this.upstream.cacheSize;
    },
    cacheValidityHours() {
      return this.upstream.cacheValidityHours;
    },
    canClearCache() {
      return this.upstream.canClearCache;
    },
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    canDelete() {
      return this.glAbilities.destroyVirtualRegistry;
    },
    artifactCount() {
      return this.upstream.artifactCount;
    },
    editPath() {
      return this.editUpstreamPathTemplate.replace(':id', this.idFromGraphQL);
    },
    showPath() {
      return this.showUpstreamPathTemplate.replace(':id', this.idFromGraphQL);
    },
    isFirstUpstream() {
      return this.index === 0;
    },
    isLastUpstream() {
      return this.index === this.upstreamsCount - 1;
    },

    hasWarning() {
      return Boolean(this.upstream.warning);
    },
    warningText() {
      return this.upstream.warning?.text || this.$options.i18n.defaultWarningText;
    },
    showButtons() {
      return (
        this.hasWarning || this.canClearCache || (this.canEdit && this.editPath) || this.canDelete
      );
    },
    cacheSizeLabel() {
      return sprintf(s__('VirtualRegistry|Cache: %{size}'), { size: this.cacheSize });
    },
    cacheValidityHoursLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|%{hours} hour cache',
          'VirtualRegistry|%{hours} hours cache',
          this.cacheValidityHours,
        ),
        { hours: this.cacheValidityHours },
      );
    },
    artifactCountLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|%{count} artifact',
          'VirtualRegistry|%{count} artifacts',
          this.artifactCount,
        ),
        { count: this.artifactCount },
      );
    },
  },
  methods: {
    reorderUpstream(direction) {
      this.$emit('reorderUpstream', direction, this.id);
    },
    clearCache() {
      this.$emit('clearCache', this.id);
    },
    deleteUpstream() {
      this.$emit('deleteUpstream', this.id);
    },
  },
  i18n: {
    moveUpLabel: s__('VirtualRegistry|Move upstream up'),
    moveDownLabel: s__('VirtualRegistry|Move upstream down'),
    clearCacheLabel: s__('VirtualRegistry|Clear cache'),
    editUpstreamLabel: s__('VirtualRegistry|Edit upstream'),
    deleteUpstreamLabel: s__('VirtualRegistry|Delete upstream'),
    defaultWarningText: s__('VirtualRegistry|There is a problem with this cached upstream'),
  },
};
</script>
<template>
  <div
    data-testid="registry-upstream-item"
    class="gl-border gl-grid gl-grid-cols-[auto_1fr] gl-gap-3 gl-rounded-base gl-bg-default gl-p-3"
  >
    <div class="gl-flex gl-items-start gl-justify-between">
      <gl-button-group vertical>
        <gl-button
          size="small"
          icon="chevron-up"
          data-testid="reorder-up-button"
          :disabled="isFirstUpstream"
          :title="$options.i18n.moveUpLabel"
          :aria-label="$options.i18n.moveUpLabel"
          @click="reorderUpstream('up')"
        />
        <gl-button
          size="small"
          icon="chevron-down"
          data-testid="reorder-down-button"
          :disabled="isLastUpstream"
          :title="$options.i18n.moveDownLabel"
          :aria-label="$options.i18n.moveDownLabel"
          @click="reorderUpstream('down')"
        />
      </gl-button-group>
    </div>
    <div class="gl-flex gl-min-w-0 gl-flex-col gl-gap-3 sm:gl-flex-row">
      <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-2">
        <div
          class="gl-flex gl-min-w-0 gl-flex-col gl-flex-wrap gl-items-start gl-gap-x-2 sm:gl-flex-row sm:gl-items-center"
        >
          <gl-link
            :href="showPath"
            class="gl-mr-2 gl-min-w-0 gl-max-w-full gl-font-bold gl-text-default"
            data-testid="upstream-name"
          >
            <gl-truncate
              :text="name"
              class="gl-min-w-0 gl-max-w-full hover:gl-underline"
              with-tooltip
            />
          </gl-link>
          <gl-link
            data-testid="upstream-url"
            :href="url"
            class="gl-min-w-0 gl-max-w-full gl-overflow-hidden gl-text-default"
          >
            <gl-truncate :text="url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
          </gl-link>
        </div>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <div v-if="cacheSize" data-testid="cache-size">
            {{ cacheSizeLabel }}
          </div>
          <div v-if="cacheSize && cacheValidityHours">&middot;</div>
          <div v-if="cacheValidityHours" data-testid="cache-validity-hours">
            {{ cacheValidityHoursLabel }}
          </div>
          <div v-if="(cacheSize || cacheValidityHours) && artifactCount">&middot;</div>
          <div v-if="artifactCount" data-testid="artifact-count">
            {{ artifactCountLabel }}
          </div>
        </div>
      </div>
      <template v-if="showButtons">
        <div
          class="gl-flex gl-flex-wrap gl-items-start gl-gap-2 sm:gl-flex-nowrap sm:gl-justify-end"
        >
          <div v-if="hasWarning" data-testid="warning-badge">
            <button
              v-gl-tooltip="warningText"
              :title="warningText"
              type="button"
              class="gl-border-none gl-bg-transparent gl-p-0"
            >
              <gl-badge variant="warning" icon="status-alert" icon-size="sm" />
            </button>
          </div>
          <gl-button
            v-if="canClearCache"
            size="small"
            category="tertiary"
            data-testid="clear-cache-button"
            @click="clearCache"
          >
            {{ $options.i18n.clearCacheLabel }}</gl-button
          >
          <gl-button
            v-if="canEdit && editPath"
            v-gl-tooltip="$options.i18n.editUpstreamLabel"
            data-testid="edit-button"
            :aria-label="$options.i18n.editUpstreamLabel"
            size="small"
            category="tertiary"
            icon="pencil"
            :href="editPath"
          />
          <gl-button
            v-if="canDelete"
            v-gl-tooltip="$options.i18n.deleteUpstreamLabel"
            data-testid="delete-button"
            :aria-label="$options.i18n.deleteUpstreamLabel"
            size="small"
            category="tertiary"
            icon="remove"
            @click="deleteUpstream"
          />
        </div>
      </template>
    </div>
  </div>
</template>
