import Wikis from '~/wikis/wikis';
import { mountApplications } from '~/wikis/edit';
import { mountWikiSidebarEntries } from '~/wikis/show';
import { mountMoreActions } from '~/wikis/more_actions';

mountApplications();
mountWikiSidebarEntries();
mountMoreActions();

export default new Wikis();
