import CircularProgressBar from './circular_progress_bar.vue';

export default {
  component: CircularProgressBar,
  title: 'ee/vue_shared/components/circular_progress_bar',
};

const Template = (args) => ({
  components: { CircularProgressBar },
  props: Object.keys(args),
  template: `<circular-progress-bar v-bind="$props" />`,
});

export const Default = Template.bind({});

Default.args = {
  percentage: 75,
};

Default.argTypes = {
  percentage: {
    control: { type: 'number', min: 1, max: 100 },
  },
};
