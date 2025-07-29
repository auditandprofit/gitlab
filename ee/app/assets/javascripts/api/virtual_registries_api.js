import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

const MAVEN_REGISTRIES_PATH =
  '/api/:version/groups/:id/-/virtual_registries/packages/maven/registries';
const MAVEN_UPSTREAM_PATH = '/api/:version/virtual_registries/packages/maven/upstreams/:id';
const MAVEN_UPSTREAM_CACHE_ENTRIES_PATH =
  '/api/:version/virtual_registries/packages/maven/upstreams/:id/cache_entries';
const MAVEN_UPSTREAM_CACHE_ENTRY_PATH =
  '/api/:version/virtual_registries/packages/maven/cache_entries/:id';

const buildMavenUpstreamApiUrl = (id) => buildApiUrl(MAVEN_UPSTREAM_PATH).replace(':id', id);

export function getMavenVirtualRegistriesList({ id }) {
  const url = buildApiUrl(MAVEN_REGISTRIES_PATH).replace(':id', id);

  return axios.get(url);
}

export function updateMavenUpstream({ id, data }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.patch(url, {
    ...data,
  });
}

export function deleteMavenUpstream({ id }) {
  const url = buildMavenUpstreamApiUrl(id);

  return axios.delete(url);
}

export function getMavenUpstreamCacheEntries({ id, params = {} }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_ENTRIES_PATH).replace(':id', id);

  return axios.get(url, { params });
}

export function deleteMavenUpstreamCacheEntry({ id }) {
  const url = buildApiUrl(MAVEN_UPSTREAM_CACHE_ENTRY_PATH).replace(':id', id);

  return axios.delete(url);
}
