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
} from '../auth/auth';

export function registerAuthHandlers(ipcMain: IpcMain): void {
  // Auth
  ipcMain.handle('auth:signUp', (_e, email: string, password: string) => signUp(email, password));
  ipcMain.handle('auth:signIn', (_e, email: string, password: string) => signIn(email, password));
  ipcMain.handle('auth:signOut', () => signOut());
  ipcMain.handle('auth:resetPassword', (_e, email: string) => resetPassword(email));
  ipcMain.handle('auth:getSession', () => getSession());
  ipcMain.handle('auth:getUser', () => getAuthUser());
  ipcMain.handle('auth:isOffline', () => getIsOffline());
  ipcMain.handle('auth:getMachineId', () => getMachineId());

  // Machine management
  ipcMain.handle('auth:registerMachine', (_e, info) => registerMachine(info));
  ipcMain.handle('auth:deactivateMachine', (_e, machineId: string) => deactivateMachine(machineId));

  // Waitlist
  ipcMain.handle('waitlist:join', (_e, feature: string) => joinWaitlist(feature));
  ipcMain.handle('waitlist:hasJoined', (_e, feature: string) => hasJoinedWaitlist(feature));
}
