import { IpcMain } from 'electron';
import {
  signUp,
  signIn,
  signOut,
  resetPassword,
  getSession,
  getAuthUser,
  getIsOffline,
  getMachineId,
  registerMachine,
  deactivateMachine,
  joinWaitlist,
  hasJoinedWaitlist,
  getRememberMe,
  setRememberMe,
  setSessionFromTokens,
  updatePassword,
} from '../auth/auth';

export function registerAuthHandlers(ipcMain: IpcMain): void {
  // Auth
  ipcMain.handle('auth:signUp', (_e, email: string, password: string) => signUp(email, password));
  ipcMain.handle('auth:signIn', (_e, email: string, password: string, rememberMe?: boolean) => signIn(email, password, rememberMe));
  ipcMain.handle('auth:signOut', () => signOut());
  ipcMain.handle('auth:resetPassword', (_e, email: string) => resetPassword(email));
  ipcMain.handle('auth:getSession', () => getSession());
  ipcMain.handle('auth:getUser', () => getAuthUser());
  ipcMain.handle('auth:isOffline', () => getIsOffline());
  ipcMain.handle('auth:getMachineId', () => getMachineId());
  ipcMain.handle('auth:getRememberMe', () => getRememberMe());
  ipcMain.handle('auth:setRememberMe', (_e, value: boolean) => setRememberMe(value));
  ipcMain.handle('auth:setSessionFromTokens', (_e, tokens: { access_token: string; refresh_token: string }) => setSessionFromTokens(tokens));
  ipcMain.handle('auth:updatePassword', (_e, newPassword: string) => updatePassword(newPassword));

  // Machine management
  ipcMain.handle('auth:registerMachine', (_e, info) => registerMachine(info));
  ipcMain.handle('auth:deactivateMachine', (_e, machineId: string) => deactivateMachine(machineId));

  // Waitlist
  ipcMain.handle('waitlist:join', (_e, feature: string) => joinWaitlist(feature));
  ipcMain.handle('waitlist:hasJoined', (_e, feature: string) => hasJoinedWaitlist(feature));
}
