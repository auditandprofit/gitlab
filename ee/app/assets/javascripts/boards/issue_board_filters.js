import issueBoardFiltersCE from '~/boards/issue_board_filters';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import searchIterationQuery from '../issues/list/queries/search_iterations.query.graphql';

export default function issueBoardFilters(apollo, fullPath, isGroupBoard) {
  const boardType = isGroupBoard ? WORKSPACE_GROUP : WORKSPACE_PROJECT;

  const fetchIterations = (searchTerm) => {
    const id = Number(searchTerm);
    let variables = { fullPath, search: searchTerm, isProject: !isGroupBoard };

    if (!Number.isNaN(id) && searchTerm !== '') {
      variables = { fullPath, id, isProject: !isGroupBoard };
    }

    return apollo
      .query({
        query: searchIterationQuery,
        variables,
      })
      .then(({ data }) => {
        return data[boardType]?.iterations.nodes;
      });
  };

  const { fetchLabels } = issueBoardFiltersCE(apollo, fullPath, isGroupBoard);

  return {
    fetchLabels,
    fetchIterations,
  };
}
