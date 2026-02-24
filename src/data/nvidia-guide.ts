import type { GpuGuideSetting } from '../types';

export const nvidiaGlobalSettings: GpuGuideSetting[] = [
  {
    setting: 'Power Management Mode',
    value: 'Prefer Maximum Performance',
    reason: 'Prevents GPU from downclocking during gameplay. Single most important GPU setting.',
    critical: true,
  },
  {
    setting: 'Low Latency Mode',
    value: 'On',
    reason: 'Reduces pre-rendered frames queue. Set to OFF for games with NVIDIA Reflex (Fortnite, Valorant, CS2).',
  },
  {
    setting: 'Max Frame Rate',
    value: 'Off',
    reason: 'Cap frames in-game instead for lower latency. Only use this if in-game cap is unavailable.',
  },
  {
    setting: 'Vertical Sync',
    value: 'Off',
    reason: 'Always OFF for competitive gaming. V-Sync adds 16-50ms of input latency.',
    critical: true,
  },
  {
    setting: 'Triple Buffering',
    value: 'Off',
    reason: 'Only useful with V-Sync (which should be off). Adds latency when enabled.',
  },
  {
    setting: 'Texture Filtering Quality',
    value: 'High Performance',
    reason: 'Slight FPS gain with negligible visual difference in competitive games.',
  },
  {
    setting: 'Texture Filtering - Anisotropic',
    value: '4x or Application-controlled',
    reason: 'Higher than 4x has diminishing returns. Let games control this when possible.',
  },
  {
    setting: 'Threaded Optimization',
    value: 'On',
    reason: 'Enables multi-threaded GPU driver. Improves performance on multi-core CPUs.',
  },
  {
    setting: 'Shader Cache Size',
    value: 'Unlimited',
    reason: 'Larger cache reduces shader compilation stutters. Especially important for UE5 games.',
  },
  {
    setting: 'G-SYNC',
    value: 'Enable for Fullscreen and Windowed',
    reason: 'Tear-free gaming with minimal latency penalty. Pair with V-Sync OFF and in-game frame cap 3 below refresh rate.',
  },
];

export const nvidiaPerGameOverrides: { game: string; setting: string; value: string; reason: string }[] = [
  { game: 'Fortnite', setting: 'Low Latency Mode', value: 'Off', reason: 'Use in-game NVIDIA Reflex On+Boost instead' },
  { game: 'Valorant', setting: 'Low Latency Mode', value: 'Off', reason: 'Use in-game NVIDIA Reflex On+Boost instead' },
  { game: 'CS2', setting: 'Low Latency Mode', value: 'Off', reason: 'Use in-game NVIDIA Reflex On+Boost instead' },
  { game: 'Arc Raiders', setting: 'Low Latency Mode', value: 'Off', reason: 'Use in-game NVIDIA Reflex if available' },
  { game: 'Black Ops 7', setting: 'Low Latency Mode', value: 'On', reason: 'Game may not have NVIDIA Reflex; use driver-level instead' },
];

export const amdGlobalSettings: GpuGuideSetting[] = [
  {
    setting: 'Graphics Profile',
    value: 'eSports',
    reason: 'Pre-configured for maximum FPS in competitive games.',
  },
  {
    setting: 'Radeon Anti-Lag',
    value: 'Enabled',
    reason: 'AMD equivalent of NVIDIA Reflex. Reduces input latency by 1-2 frames.',
    critical: true,
  },
  {
    setting: 'Wait for Vertical Refresh',
    value: 'Off, unless application specifies',
    reason: 'Same as V-Sync off. Never enable for competitive games.',
    critical: true,
  },
  {
    setting: 'Texture Filtering Quality',
    value: 'Performance',
    reason: 'Minor FPS gain with minimal visual impact.',
  },
  {
    setting: 'Surface Format Optimization',
    value: 'Enabled',
    reason: 'Optimizes texture formats for performance.',
  },
  {
    setting: 'Tessellation Mode',
    value: 'Override application settings → Off',
    reason: 'Disables tessellation for FPS gain. Minimal visual impact in competitive games.',
  },
  {
    setting: 'FreeSync',
    value: 'Enabled',
    reason: 'AMD adaptive sync. Enable in display settings with V-Sync OFF in games.',
  },
];

export const gsyncSetupSteps = [
  'Open NVIDIA Control Panel → Display → Set up G-SYNC',
  'Check "Enable G-SYNC, G-SYNC Compatible"',
  'Select "Enable for full screen and windowed mode"',
  'Go to Manage 3D Settings → Global Settings',
  'Set "Vertical sync" to "Off"',
  'Set "Max Frame Rate" to your monitor refresh rate minus 3 (e.g., 237 for 240Hz)',
  'In each game: Set V-Sync OFF, cap FPS to monitor refresh minus 3',
  'This gives you tear-free gaming with the lowest possible input latency',
];
