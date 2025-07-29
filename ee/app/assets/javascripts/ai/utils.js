import { duoChatGlobalState } from '~/super_sidebar/constants';
import { setCookie } from '~/lib/utils/common_utils';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
} from 'ee/ai/tanuki_bot/constants';

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * setCookie wrapper with duo agentic mode constances.
 *
 * @param {isAgenticMode} Boolean - Value to save
 * @returns {void}
 */
export const saveDuoAgenticModePreference = (isAgenticMode) => {
  setCookie(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
    expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  });
};

/**
 * Swith duo chat based on agenticMode value and save to cookie based on
 * saveCookie value.
 *
 * @param {agenticMode} Boolean - Agentic mode state
 * @param {saveCookie} Boolean - Save to cookie flag
 * @returns {void}
 */

export const setAgenticMode = (agenticMode = true, saveCookie = false) => {
  duoChatGlobalState.isShown = !agenticMode;
  duoChatGlobalState.isAgenticChatShown = agenticMode;

  if (saveCookie) {
    saveDuoAgenticModePreference(agenticMode);
  }
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * @param {question} String - Prompt to send to the chat endpoint
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 */
export const sendDuoChatCommand = ({ question, resourceId, variables = {} } = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }
  setAgenticMode(false, true);

  window.requestIdleCallback(() => {
    duoChatGlobalState.commands.push({
      question,
      resourceId,
      variables,
    });
  });
};

export const clearDuoChatCommands = () => {
  duoChatGlobalState.commands = [];
};

/**
 * Converts a text string into a URL-friendly format for event tracking.
 *
 * - Converts to lowercase
 * - Removes special characters
 * - Replaces spaces with underscores
 * - Limits length to 50 characters
 *
 * @param {string} text - The text to convert
 * @returns {string} The formatted event label
 */
export const generateEventLabelFromText = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
};

export const utils = {
  concatStreamedChunks,
  generateEventLabelFromText,
};
