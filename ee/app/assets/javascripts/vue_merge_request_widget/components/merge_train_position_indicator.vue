<script>
import { isNumber } from 'lodash';
import { GlLink } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { STATUS_OPEN } from '~/issues/constants';

export default {
  name: 'MergeTrainPositionIndicator',
  components: {
    GlLink,
  },
  props: {
    mergeRequestState: {
      type: String,
      required: false,
      default: null,
    },
    mergeTrainsCount: {
      type: Number,
      required: false,
      default: null,
    },
    mergeTrainsPath: {
      type: String,
      required: false,
      default: null,
    },
    mergeTrainCar: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isMergeRequestOpen() {
      return this.mergeRequestState === STATUS_OPEN;
    },
    mergeTrainIndex() {
      return this.mergeTrainCar?.index;
    },
    message() {
      if (this.mergeTrainIndex === 0) {
        return s__(
          'mrWidget|A new merge train has started and this merge request is the first of the queue.',
        );
      }

      if (isNumber(this.mergeTrainIndex) && isNumber(this.mergeTrainsCount)) {
        return sprintf(
          s__('mrWidget|This merge request is #%{mergeTrainPosition} of %{total} in queue.'),
          {
            mergeTrainPosition: this.mergeTrainIndex + 1,
            total: this.mergeTrainsCount,
          },
        );
      }

      return null;
    },
  },
  watch: {
    mergeTrainCar(currentCar, oldCar) {
      if (!this.isMergeRequestOpen) {
        return;
      }

      // if an old merge train car existed and the current
      // merge train car is null then the MR was removed
      // from the merge train.
      if (oldCar && !currentCar) {
        this.$toast?.show(s__('mrWidget|Merge request was removed from the merge train.'));
      }
    },
  },
};
</script>

<template>
  <div v-if="message" class="pt-2 pb-2 pl-3 plr-3 merge-train-position-indicator">
    <div class="media-body gl-text-subtle">
      {{ message }}
      <gl-link v-if="mergeTrainsPath" :href="mergeTrainsPath">
        {{ s__('mrWidget|View merge train details.') }}
      </gl-link>
    </div>
  </div>
</template>
