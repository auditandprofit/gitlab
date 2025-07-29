import StateTooltip from './state_tooltip.vue';

export default {
  component: StateTooltip,
  title: 'ee/related_items_tree/StateTooltip',
};

const Template = (args, { argTypes }) => ({
  components: { StateTooltip },
  props: Object.keys(argTypes),
  template: `
  <div>
    <span ref="targetElement">example text</span>
    <state-tooltip :get-target-ref="() => $refs.targetElement" v-bind="$props" />
  </div>`,
});

export const Default = Template.bind({});
Default.args = {
  isOpen: false,
  path: '/foo/bar#1',
  createdAt: '2021-01-01',
  closedAt: '2022-01-01',
};
