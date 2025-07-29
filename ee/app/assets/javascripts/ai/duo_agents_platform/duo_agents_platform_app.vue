<script>
import { AGENT_PLATFORM_INDEX_COMPONENT_NAME } from './constants';

export default {
  name: 'DuoAgentsPlatformApp',
  keepAliveComponents: [AGENT_PLATFORM_INDEX_COMPONENT_NAME],
};
</script>
<template>
  <div id="agents-platform-app">
    <keep-alive :include="$options.keepAliveComponents">
      <router-view />
    </keep-alive>
  </div>
</template>
