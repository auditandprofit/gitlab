import showToast from '~/vue_shared/plugins/global_toast';
import MavenRegistryDetailsApp from './maven_registry_details_app.vue';

export default {
  component: MavenRegistryDetailsApp,
  title: 'ee/virtual_registries/maven_registry_details',
  argTypes: {
    reorderUpstream: {
      description: 'Emitted when an upstream is reordered',
      action: 'reorderUpstream',
      table: {
        type: {
          summary: '(direction: "up" | "down", upstreamId: string) => void',
        },
      },
    },
    createUpstream: {
      description: 'Emitted when a new upstream is created',
      action: 'createUpstream',
      table: {
        type: {
          summary:
            '(upstream: { name: string, url: string, cacheValidityHours?: number, description?: string, username?: string, password?: string }) => void',
        },
      },
    },
    editUpstream: {
      description: 'Emitted when a upstream is edited',
      action: 'editUpstream',
      table: {
        type: {
          summary:
            '(upstream: { name: string, url: string, cacheValidityHours?: number, description?: string, username?: string, password?: string }) => void',
        },
      },
    },
    testUpstream: {
      description: 'Emitted when an upstream is tested',
      action: 'testUpstream',
      table: {
        type: {
          summary:
            '(upstream: { name: string, url: string, cacheValidityHours?: number, description?: string, username?: string, password?: string }) => void',
        },
      },
    },
    clearCache: {
      description: 'Emitted when the cache is cleared',
      action: 'clearCache',
      table: {
        type: {
          summary: '(upstreamId: string) => void',
        },
      },
    },
    deleteUpstream: {
      description: 'Emitted when the upstream is deleted',
      action: 'deleteUpstream',
      table: {
        type: {
          summary: '(upstreamId: string) => void',
        },
      },
    },
  },
};

const Template = (_, { argTypes }) => ({
  components: { MavenRegistryDetailsApp },
  props: Object.keys(argTypes),
  provide: {
    glAbilities: {
      createVirtualRegistry: true,
      updateVirtualRegistry: true,
    },
    registryEditPath: 'edit_path',
    editUpstreamPathTemplate: 'path/:id/edit',
    showUpstreamPathTemplate: 'path/:id',
  },
  template:
    '<maven-registry-details-app v-bind="$props" @createUpstream="createUpstream" @testUpstream="testUpstream" @reorderUpstream="reorderUpstream" @clearCache="clearCache" @editUpstream="editUpstream" @deleteUpstream="deleteUpstream" />',
});

export const Default = Template.bind({});
Default.args = {
  registry: {
    id: 1,
    name: 'Registry title',
    description: 'Registry description',
    storageSize: '0 B',
  },
  upstreams: {
    count: 2,
    nodes: [
      {
        id: 1,
        name: 'Upstream title',
        description: 'Upstream description',
        url: 'http://maven.org/test',
        cacheValidityHours: 24,
        cacheSize: '100 MB',
        canClearCache: true,
        artifactCount: 100,
        position: 1,
        warning: {
          text: 'There is a problem with this cached upstream',
        },
      },
      {
        id: 2,
        name: 'Upstream title 2',
        description: 'Upstream description 2',
        url: 'http://maven.org/test2',
        cacheValidityHours: 1,
        cacheSize: '11.2 GB',
        canClearCache: false,
        artifactCount: 1,
        position: 2,
      },
    ],
    pageInfo: {
      startCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
      hasNextPage: false,
      hasPreviousPage: false,
      endCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
    },
  },
  canTestUpstream: true,
  createUpstream: (upstream) => {
    showToast(`Upstream create called for "${upstream.name}"`);
  },
  testUpstream: (upstream) => {
    showToast(`Upstream test called for "${upstream.name}"`);
  },
  reorderUpstream: (direction, upstreamId) => {
    showToast(`Upstream reorder called for "${upstreamId}" in direction "${direction}"`);
  },
  clearCache: (upstreamId) => {
    showToast(`Cache clear called for "${upstreamId}"`);
  },
  deleteUpstream: (upstreamId) => {
    showToast(`Upstream delete called for "${upstreamId}"`);
  },
};

Default.parameters = {
  docs: {
    description: {
      story:
        'Note that the `MavenRegistryDetailsApp` component delegates CRUD actions like creating, testing, reordering, and deleting upstreams and clearing cache to its parent via emits.',
    },
  },
};
