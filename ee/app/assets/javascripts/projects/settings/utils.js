export const getAccessLevels = (accessLevels = {}) => {
  const total = accessLevels.edges?.length;
  const accessLevelTypes = { total, users: [], groups: [], deployKeys: [], roles: [] };

  (accessLevels.edges || []).forEach(({ node }) => {
    if (node.user) {
      const src = node.user.avatarUrl;
      accessLevelTypes.users.push({ src, ...node.user });
    } else if (node.group) {
      accessLevelTypes.groups.push(node.group);
    } else if (node.deployKey) {
      accessLevelTypes.deployKeys.push(node.deployKey);
    } else {
      accessLevelTypes.roles.push(node.accessLevel);
    }
  });

  return accessLevelTypes;
};

export const getAccessLevelInputFromEdges = (edges) => {
  return edges.flatMap(({ node }) => {
    const result = {};

    if (node.accessLevel !== undefined) {
      result.accessLevel = node.accessLevel;
    }

    if (node.group?.id !== undefined) {
      result.groupId = node.group.id;
      delete result.accessLevel; // backend only expects groupId
    }

    if (node.user?.id !== undefined) {
      result.userId = node.user.id;
      delete result.accessLevel; // backend only expects userId
    }

    if (node.deployKey?.id !== undefined) {
      result.deployKeyId = node.deployKey.id;
      delete result.accessLevel; // backend only expects deployKeyId
    }

    return Object.keys(result).length > 0 ? [result] : [];
  });
};
