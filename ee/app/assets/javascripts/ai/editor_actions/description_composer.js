import eventHub from '~/vue_shared/components/markdown/eventhub';
import { s__ } from '~/locale';

export const descriptionComposerAction = () => ({
  icon: 'pencil',
  title: s__('AI|Write with GitLab Duo'),
  handler() {
    eventHub.$emit('SHOW_COMPOSER');

    return Promise.resolve(null);
  },
});
