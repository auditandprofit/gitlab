import '~/pages/admin/users/edit';
import initPasswordValidator from 'ee/password/password_validator';
import { pipelineMinutes } from '../pipeline_minutes';

pipelineMinutes();
initPasswordValidator({ allowNoPassword: true });
