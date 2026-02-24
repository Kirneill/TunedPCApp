import type { BiosGuideStep } from '../types';

export const biosGuideSteps: BiosGuideStep[] = [
  {
    id: 'xmp-expo',
    title: 'Enable XMP / EXPO Profile',
    description: 'Your RAM runs at a default speed (e.g., 4800 MHz) until you enable its rated speed profile.',
    details: 'Navigate to your BIOS memory settings (often under "OC" or "Tweaker" tab). Look for "XMP" (Intel) or "EXPO" (AMD) and enable Profile 1. This can provide 10-20% improvement in frame times since games are heavily memory-bandwidth dependent.',
    impact: '10-20% frame time improvement',
  },
  {
    id: 'pbo2',
    title: 'Enable PBO2 + Curve Optimizer (AMD)',
    description: 'Precision Boost Overdrive 2 with Curve Optimizer allows your CPU to boost higher and more efficiently.',
    details: 'In BIOS under AMD Overclocking > PBO: Set PBO to "Advanced", Scalar to "Auto" or "Manual 1x". Under Curve Optimizer: Set to "All Cores", "Negative", start with magnitude 15-20. Test stability with games and benchmarks. For Intel: Enable "Turbo Boost Max 3.0" and "Speed Shift Technology" instead.',
    warning: 'Start conservative (negative 15) and increase gradually. Too aggressive = crashes.',
    impact: '5-15% boost clock improvement',
  },
  {
    id: 'fclk',
    title: 'Set FCLK / Infinity Fabric Clock (AMD)',
    description: 'The Infinity Fabric clock should match your memory clock for 1:1 ratio (best latency).',
    details: 'For DDR5-6000: Set FCLK to 3000 MHz (half the RAM speed). For DDR4-3600: Set FCLK to 1800 MHz. Going above 1:1 ratio adds latency penalty. If unstable, lower RAM speed to match FCLK sweet spot. For Intel: This setting is automatic.',
    warning: 'FCLK above 2000 MHz (DDR5-8000+) is often unstable. 6000 MHz DDR5 with 3000 FCLK is the sweet spot.',
    impact: 'Reduced memory latency (5-10ms less in games)',
  },
  {
    id: 'cppc',
    title: 'Enable CPPC / Preferred Cores',
    description: 'Allows the CPU to identify and use its fastest cores for single-threaded game workloads.',
    details: 'AMD: Enable "CPPC" and "CPPC Preferred Cores" in BIOS. This lets the OS scheduler send game threads to the best-performing cores. Intel: Enable "Thread Director" (12th gen+). Both improve single-thread performance which directly impacts game FPS.',
    impact: '2-5% FPS in CPU-limited scenarios',
  },
  {
    id: 'cstates',
    title: 'C-States Configuration',
    description: 'C-States control CPU power saving. Disabling can reduce micro-stutters but increases power/heat.',
    details: 'For maximum performance: Set "Global C-State Control" to "Disabled" and "Power Supply Idle Control" to "Typical Current Idle". This prevents the CPU from entering deep sleep states between frames. For daily use with gaming: Leave C-States enabled and rely on the Windows Ultimate Performance power plan instead.',
    warning: 'Disabling C-States increases idle power by 20-40W and CPU temperature. Only recommended for dedicated gaming PCs.',
    impact: 'Reduced micro-stutters (marginal on modern CPUs)',
  },
  {
    id: 'rebar',
    title: 'Enable Resizable BAR / Smart Access Memory',
    description: 'Allows the CPU to access the entire GPU VRAM at once instead of 256MB chunks.',
    details: 'Prerequisites: UEFI boot mode (not Legacy/CSM), Secure Boot enabled, compatible GPU (RTX 30/40, RX 6000/7000+). In BIOS: Enable "Above 4G Decoding" first, then enable "Resizable BAR" or "Re-Size BAR Support". Verify in GPU-Z or NVIDIA Control Panel after reboot.',
    impact: '2-10% FPS depending on the game',
  },
  {
    id: 'secure-boot',
    title: 'Verify Secure Boot & TPM (Anti-Cheat)',
    description: 'Modern anti-cheats (Vanguard, Ricochet) require Secure Boot and TPM 2.0 enabled.',
    details: 'Check: Settings > Update & Security > Device Security. If TPM or Secure Boot is off, enable in BIOS. TPM is usually under "Security" tab. Secure Boot under "Boot" tab — must use UEFI mode, not Legacy/CSM. Without these, Valorant will not launch and other games may have issues.',
    impact: 'Required for Valorant, recommended for all competitive games',
  },
  {
    id: 'virtualization',
    title: 'Disable Virtualization (Optional)',
    description: 'SVM/VT-x enables Hyper-V and WSL. Disabling can slightly improve game performance.',
    details: 'If you do NOT use: WSL, Docker, Android emulators, or Hyper-V VMs — you can disable "SVM Mode" (AMD) or "Intel Virtualization Technology" (Intel) in BIOS. This disables the hypervisor layer which adds ~1-3% overhead. If you use any of these tools, leave it enabled.',
    warning: 'Disabling breaks WSL, Docker, Android Studio emulator, and Hyper-V features.',
    impact: '1-3% FPS improvement (removes hypervisor overhead)',
  },
];
