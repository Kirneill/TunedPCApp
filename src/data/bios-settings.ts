import type { BiosCategory, BiosSetting } from '../types';

export const biosCategories: BiosCategory[] = [
  {
    id: 'memory',
    title: 'RAM Speed',
    description: 'Faster RAM means more FPS in competitive games',
    platform: 'both',
    order: 1,
  },
  {
    id: 'cpu',
    title: 'CPU Speed',
    description: 'Get the most speed out of your processor',
    platform: 'both',
    order: 2,
  },
  {
    id: 'gpu-pcie',
    title: 'Graphics Card',
    description: 'GPU memory access and connection speed',
    platform: 'both',
    order: 3,
  },
  {
    id: 'security-perf',
    title: 'Windows Security vs FPS',
    description: 'Windows features that slow down your games',
    platform: 'both',
    order: 4,
  },
  {
    id: 'power',
    title: 'Power and Cooling',
    description: 'Keep your CPU running at top speed',
    platform: 'both',
    order: 5,
  },
];

export const biosSettings: BiosSetting[] = [
  // ─── Memory Performance ──────────────────────────────────
  {
    id: 'xmp-expo',
    categoryId: 'memory',
    title: 'Unlock Full RAM Speed (+10-20% FPS)',
    description:
      'Your RAM is probably running at half its rated speed right now. Most PCs ship this way. Enabling this one setting is the single biggest FPS boost you can get from BIOS.',
    details:
      'Look for "XMP" (Intel) or "EXPO" (AMD) in your BIOS and set it to Profile 1. This unlocks the full speed your RAM was designed for. For example, going from 4800 MHz to 6000 MHz DDR5 can give you 10-20% more FPS in games like Valorant and CS2.',
    recommendedValue: 'Profile 1 Enabled',
    impact: 'high',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    automatable: true,
    vendorNav: {
      asus: 'AI Tweaker > XMP > Profile 1',
      msi: 'OC > XMP > Profile 1',
      gigabyte: 'Tweaker > Extreme Memory Profile (XMP) > Profile 1',
      asrock: 'OC Tweaker > DRAM Configuration > XMP > Profile 1',
    },
  },
  {
    id: 'fclk-ratio',
    categoryId: 'memory',
    title: 'Match CPU-to-RAM Speed (AMD only)',
    description:
      'Your AMD processor has an internal link to your RAM. When this link speed matches your RAM speed, you get the lowest possible delay between CPU and memory.',
    details:
      'For Ryzen 7000/9000 (AM5): Set FCLK to 2000 MHz when using DDR5-6000 RAM. For Ryzen 5000 (AM4): Set FCLK to half your RAM speed (e.g., DDR4-3600 = FCLK 1800). Going above FCLK 1900 on Ryzen 5000 causes stability issues on most chips.',
    recommendedValue: 'DDR5-6000 = FCLK 2000 MHz',
    impact: 'high',
    risk: 'caution',
    platform: 'amd',
    requiresReboot: true,
    automatable: true,
    warning:
      'FCLK above 2000 MHz can cause crashes on many chips. If your PC becomes unstable, lower this to 1800 and use DDR5-5600 RAM speed.',
    vendorNav: {
      asus: 'AI Tweaker > FCLK Frequency > 2000',
      msi: 'OC > AMD Overclocking > FCLK Frequency > 2000',
      gigabyte: 'Tweaker > Advanced Memory Settings > Infinity Fabric Frequency > 2000',
      asrock: 'OC Tweaker > FCLK Frequency > 2000',
    },
  },
  {
    id: 'uclk-mclk',
    categoryId: 'memory',
    title: 'Force Full-Speed RAM Link (AMD only)',
    description:
      'Some motherboards secretly run your RAM connection at half speed to play it safe. This setting forces it to run at full speed.',
    details:
      'After enabling XMP/EXPO, check that your board isn\'t silently using a slower "2:1 mode." Look for "UCLK DIV1 Mode" or "UCLK==MEMCLK" and set it to Enabled. If left on Auto, some boards cut your RAM link speed in half, which doubles memory delay.',
    recommendedValue: 'Enabled / UCLK==MEMCLK',
    impact: 'medium',
    risk: 'safe',
    platform: 'amd',
    requiresReboot: true,
    automatable: true,
    vendorNav: {
      asus: 'AI Tweaker > UCLK DIV1 Mode > Enabled',
      msi: 'OC > AMD Overclocking > UCLK == MEMCLK',
      gigabyte: 'Tweaker > Advanced Memory Settings > UCLK Mode > UCLK==MEMCLK',
      asrock: 'OC Tweaker > UCLK DIV1 Mode > Enabled',
    },
  },

  // ─── CPU Performance ─────────────────────────────────────
  {
    id: 'pbo-curve-optimizer',
    categoryId: 'cpu',
    title: 'Automatic CPU Speed Boost (AMD only)',
    description:
      'Lets your AMD Ryzen CPU run faster and cooler at the same time by fine-tuning its voltage. Free performance with no downsides when done right.',
    details:
      'Set PBO to "Advanced" mode. Under Curve Optimizer, select "All Cores", "Negative", start with magnitude 15 (safe starting point). If stable after a full day of gaming, increase to 20, then 25. Never go past 30. If you get crashes, reduce by 5.',
    recommendedValue: 'PBO Advanced, CO All Cores Negative -15 (safe start)',
    impact: 'high',
    risk: 'caution',
    platform: 'amd',
    requiresReboot: true,
    automatable: true,
    warning:
      'Start at -15 (safe for virtually all chips). Going too high causes random crashes. Play for a full day before increasing. If crashes happen, lower by 5.',
    vendorNav: {
      asus: 'AI Tweaker > AMD Overclocking > PBO > Advanced > Curve Optimizer',
      msi: 'OC > AMD Overclocking > PBO > Advanced > Curve Optimizer',
      gigabyte: 'Tweaker > PBO > Advanced > Curve Optimizer',
      asrock: 'OC Tweaker > AMD Overclocking > PBO > Advanced > Curve Optimizer',
    },
  },
  {
    id: 'intel-power-limits',
    categoryId: 'cpu',
    title: 'CPU Power Protection (Intel 13th/14th Gen)',
    description:
      'Many motherboards let Intel CPUs draw unlimited power, which Intel confirmed causes permanent CPU damage over time. This sets safe limits.',
    details:
      'IMPORTANT for i9-13900K/14900K owners. Intel confirmed that unlimited power causes permanent chip degradation. Update your BIOS to the latest version, then set Power Limit 1 and 2 to 253W and current limit to 307A. Disable "Multi-Core Enhancement" (MCE).',
    recommendedValue: 'PL1=253W, PL2=253W, ICCMAX=307A',
    impact: 'medium',
    risk: 'caution',
    platform: 'intel',
    requiresReboot: true,
    automatable: true,
    warning:
      'These are Intel\'s own recommended limits. Running without them has been proven to permanently damage 13th/14th gen CPUs over time.',
    vendorNav: {
      asus: 'AI Tweaker > Internal CPU Power Management > PL1/PL2 > 253',
      msi: 'OC > CPU Features > Long/Short Duration Power Limit > 253',
      gigabyte: 'Tweaker > Advanced CPU Settings > PL1/PL2 > 253',
      asrock: 'OC Tweaker > CPU Configuration > Power Limit > 253',
    },
  },
  {
    id: 'cppc-preferred',
    categoryId: 'cpu',
    title: 'Smart Core Selection',
    description:
      'Tells Windows to use your CPU\'s fastest cores for gaming. Every CPU has some cores that are slightly faster than others.',
    details:
      'AMD: Enable "CPPC" and "CPPC Preferred Cores" in BIOS. Intel (12th gen+): Enable "Thread Director". This helps Windows send your game to the best-performing cores, which directly improves FPS.',
    recommendedValue: 'Enabled',
    impact: 'medium',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    automatable: true,
    vendorNav: {
      asus: 'Advanced > CPU Configuration > CPPC > Enabled',
      msi: 'OC > CPU Features > CPPC > Enabled',
      gigabyte: 'Settings > Platform Power > CPPC > Enabled',
      asrock: 'Advanced > CPU Configuration > CPPC > Enabled',
    },
  },
  {
    id: 'c-states',
    categoryId: 'cpu',
    title: 'CPU Power Saving (leave on)',
    description:
      'Some guides tell you to disable this for gaming. That advice is outdated. Modern CPUs wake up so fast that disabling this wastes power with zero FPS benefit.',
    details:
      'Leave C-States enabled. Modern CPUs transition out of sleep in microseconds, so there\'s no measurable FPS difference. The only thing disabling does is increase your power bill by 20-40W at idle. Use the Ultimate Performance power plan in Windows instead.',
    recommendedValue: 'Enabled (leave default)',
    impact: 'low',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    automatable: true,
    warning:
      'Modern CPUs wake up so fast that disabling this has zero measurable FPS benefit. It only increases your electricity usage. Leave it enabled.',
    vendorNav: {
      asus: 'Advanced > CPU Configuration > Global C-state Control',
      msi: 'OC > CPU Features > Global C-state Control',
      gigabyte: 'Settings > Platform Power > Global C-state Control',
      asrock: 'Advanced > CPU Configuration > Global C-state Control',
    },
  },

  // ─── GPU & PCIe ──────────────────────────────────────────
  {
    id: 'rebar-sam',
    categoryId: 'gpu-pcie',
    title: 'Full GPU Memory Access',
    description:
      'By default, your CPU can only access a tiny slice of your GPU\'s memory at a time. This setting removes that bottleneck and lets the CPU use all of it at once.',
    details:
      'Requirements: Your PC must boot in UEFI mode (not Legacy), and you need a compatible GPU (RTX 3000/4000 or RX 6000/7000+). Step 1: Enable "Above 4G Decoding". Step 2: Enable "Resizable BAR" or "Re-Size BAR Support". Check NVIDIA Control Panel after reboot to confirm it\'s active.',
    recommendedValue: 'Enabled (requires Above 4G Decoding first)',
    impact: 'high',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    automatable: true,
    vendorNav: {
      asus: 'Advanced > PCI Subsystem Settings > Above 4G Decoding > Enabled, then Re-Size BAR Support > Enabled',
      msi: 'Settings > Advanced > Above 4G Memory > Enabled, then Re-Size BAR Support > Enabled',
      gigabyte: 'Settings > IO Ports > Above 4G Decoding > Enabled, then Re-Size BAR Support > Enabled',
      asrock: 'Advanced > Above 4G Decoding > Enabled, then Re-Size BAR Support > Enabled',
    },
  },
  {
    id: 'pcie-gen',
    categoryId: 'gpu-pcie',
    title: 'GPU Connection Speed',
    description:
      'Make sure your graphics card is connected at full speed. Some motherboards default to a slower connection mode.',
    details:
      'Modern GPUs use PCIe Gen 4. You can check your current speed in GPU-Z. If it shows Gen 3, go into BIOS and force Gen 4 for the GPU slot. Gen 5 is available on some newer boards but makes no noticeable difference for current GPUs.',
    recommendedValue: 'Auto or Gen 4 (for GPU slot)',
    impact: 'low',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    vendorNav: {
      asus: 'Advanced > PCI Subsystem > PCIEX16 Link Speed > Auto/Gen4',
      msi: 'Settings > Advanced > PCI Express Settings > Gen4',
      gigabyte: 'Settings > IO Ports > PCIEX16 Link Speed > Auto/Gen4',
      asrock: 'Advanced > Chipset Configuration > PCIE Link Speed > Auto/Gen4',
    },
  },

  // ─── Security vs Performance ──────────────────────────────
  {
    id: 'vbs-hvci',
    categoryId: 'security-perf',
    title: 'Windows Security Layer (costs 5-15% FPS)',
    description:
      'Windows runs an invisible security layer that checks everything your CPU does. It\'s great for security but costs you 5-15% FPS in every game.',
    details:
      'You can turn this off from Windows -- no BIOS needed. Go to Settings > Privacy and Security > Windows Security > Device Security > Core Isolation > Memory Integrity > Off. Restart your PC after changing this.',
    recommendedValue: 'Disabled for gaming PCs',
    impact: 'high',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    automatable: true,
    warning:
      'This protects against advanced malware. Only turn it off if this PC is mainly used for gaming.',
    vendorNav: {
      asus: 'No BIOS change needed -- disable from Windows Settings or Registry',
      msi: 'No BIOS change needed -- disable from Windows Settings or Registry',
      gigabyte: 'No BIOS change needed -- disable from Windows Settings or Registry',
      asrock: 'No BIOS change needed -- disable from Windows Settings or Registry',
    },
  },
  {
    id: 'virtualization',
    categoryId: 'security-perf',
    title: 'Virtual Machine Support (1-3% FPS cost)',
    description:
      'This lets your PC run virtual machines and developer tools. If you ONLY use this PC for gaming, turning it off gives you a small FPS boost.',
    details:
      'If you don\'t use WSL, Docker, Android emulators, or virtual machines, you can safely turn this off. In BIOS, look for "SVM Mode" (AMD) or "Intel Virtualization Technology" (Intel) and set it to Disabled.',
    recommendedValue: 'Enabled (unless you exclusively game on this PC)',
    impact: 'low',
    risk: 'caution',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    automatable: true,
    warning:
      'Turning this off breaks WSL, Docker, Android emulators, and virtual machines. Only disable if you exclusively game on this PC.',
    vendorNav: {
      asus: 'Advanced > CPU Configuration > SVM Mode (AMD) / Intel Virtualization (Intel)',
      msi: 'OC > CPU Features > SVM Mode / Intel VT',
      gigabyte: 'Tweaker > Advanced CPU Settings > SVM Mode / Intel VT',
      asrock: 'Advanced > CPU Configuration > SVM Mode / Intel VT',
    },
  },
  {
    id: 'iommu',
    categoryId: 'security-perf',
    title: 'Device Memory Virtualization (slightly improves FPS)',
    description:
      'IOMMU adds a hardware translation step when devices access memory. Disabling it slightly improves FPS in most games.',
    details:
      'Look for "IOMMU" in your BIOS (AMD) or "VT-d" (Intel). This feature is mainly used for passing hardware devices to virtual machines. If you don\'t use GPU passthrough to VMs, disabling it may reduce overhead on some systems.',
    recommendedValue: 'Disabled for gaming PCs',
    impact: 'medium',
    risk: 'caution',
    platform: 'both',
    requiresReboot: true,
    detectable: false,
    automatable: true,
    warning:
      'Disabling is safe for dedicated gaming PCs. If you use WSL2, Docker, Hyper-V, or virtual machines, verify your setup still works after disabling.',
    vendorNav: {
      asus: 'Advanced > CPU Configuration > VT-d (Intel) / Advanced > AMD CBS > NBIO > IOMMU (AMD)',
      msi: 'OC > CPU Features > Intel VT-d Tech (Intel) / IOMMU (AMD)',
      gigabyte: 'Settings > IO Ports > Intel VT-d (Intel) / Settings > AMD CBS > NBIO > IOMMU (AMD)',
      asrock: 'Advanced > Chipset Configuration > VT-d / IOMMU',
    },
  },
  {
    id: 'secure-boot-tpm',
    categoryId: 'security-perf',
    title: 'Anti-Cheat Requirements (keep on)',
    description:
      'Valorant, Call of Duty, and other games with anti-cheat require these to be enabled. Turning them off will prevent those games from launching.',
    details:
      'Press Windows+R, type "msinfo32" and check: Secure Boot State should be "On" and TPM should show version 2.0. If either is off, enable them in BIOS. TPM is usually under the "Security" tab. Secure Boot is under the "Boot" tab.',
    recommendedValue: 'Enabled',
    impact: 'low',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    detectable: true,
    vendorNav: {
      asus: 'Boot > Secure Boot > Enabled; Advanced > Security > TPM',
      msi: 'Settings > Security > Secure Boot > Enabled; Settings > Security > TPM',
      gigabyte: 'Boot > Secure Boot > Enabled; Settings > Miscellaneous > AMD fTPM / Intel PTT',
      asrock: 'Security > Secure Boot > Enabled; Advanced > Trusted Computing > TPM',
    },
  },

  // ─── Power & Thermals ────────────────────────────────────
  {
    id: 'boost-enable',
    categoryId: 'power',
    title: 'CPU Speed Boost (must be on)',
    description:
      'This is what lets your CPU run at its advertised speeds. Without it, your CPU is stuck at its slowest speed, costing you 30-40% performance.',
    details:
      'AMD: Look for "Core Performance Boost" and make sure it\'s Enabled. Intel: Look for "Intel Turbo Boost" and "Turbo Boost Max 3.0" -- both must be Enabled. BIOS updates sometimes reset this to Disabled, so check after every update.',
    recommendedValue: 'Enabled',
    impact: 'high',
    risk: 'safe',
    platform: 'both',
    requiresReboot: true,
    automatable: true,
    vendorNav: {
      asus: 'AI Tweaker > Core Performance Boost (AMD) / Turbo Mode (Intel)',
      msi: 'OC > CPU Features > Core Performance Boost / Intel Turbo Boost',
      gigabyte: 'Tweaker > Core Performance Boost / Turbo Boost',
      asrock: 'OC Tweaker > CPU Configuration > Core Performance Boost / Turbo Boost',
    },
  },
  {
    id: 'thermal-limit',
    categoryId: 'power',
    title: 'CPU Temperature Limit (AMD only)',
    description:
      'Sets the maximum temperature your CPU is allowed to reach before it slows down. Setting this wrong can cost performance or risk damage.',
    details:
      'For X3D chips (7800X3D, 9800X3D): AMD says 89C max due to the special 3D stacked cache. For other Ryzen CPUs (7000/9000 series): 95C is perfectly normal -- AMD designed them to run at this temperature. Setting it lower than intended forces your CPU to slow down unnecessarily.',
    recommendedValue: '89C for X3D, 95C for non-X3D Zen 4/5',
    impact: 'low',
    risk: 'advanced',
    platform: 'amd',
    requiresReboot: true,
    automatable: true,
    warning:
      'Do NOT set above 89C on X3D chips (7800X3D, 9800X3D) -- the 3D stacked cache can\'t handle higher temps. Regular Ryzen chips are fine at 95C.',
    vendorNav: {
      asus: 'AI Tweaker > AMD Overclocking > Platform Thermal Throttle Limit',
      msi: 'OC > AMD Overclocking > tCTL Offset (or Platform Thermal Throttle)',
      gigabyte: 'Tweaker > PBO > Platform Thermal Throttle',
      asrock: 'OC Tweaker > AMD Overclocking > Platform Thermal Throttle',
    },
  },
  {
    id: 'fan-curve',
    categoryId: 'power',
    title: 'Fan Speed for Gaming',
    description:
      'Your CPU can only run at top speed if your fans keep it cool enough. The default "quiet" fan profile sacrifices performance for silence.',
    details:
      'Most BIOSes have fan presets: Silent, Standard, Performance, or Full Speed. For gaming, switch to "Performance" mode. This makes fans spin faster when your CPU gets hot, keeping temperatures low so your CPU can maintain its highest speeds.',
    recommendedValue: 'Performance preset or custom aggressive curve',
    impact: 'medium',
    risk: 'safe',
    platform: 'both',
    requiresReboot: false,
    vendorNav: {
      asus: 'Monitor > Q-Fan Configuration > CPU Fan Profile > Performance',
      msi: 'Hardware Monitor > Fan Control > CPU Fan > Smart Mode > Performance',
      gigabyte: 'Smart Fan 5 (F6 shortcut) > CPU Fan > Performance',
      asrock: 'H/W Monitor > Fan Control > CPU Fan > Performance',
    },
  },
];

export function getSettingsForPlatform(cpuName: string | undefined): BiosSetting[] {
  if (!cpuName) return biosSettings;
  const isAmd = /amd|ryzen/i.test(cpuName);
  const isIntel = /intel|core/i.test(cpuName);
  if (!isAmd && !isIntel) return biosSettings;
  return biosSettings.filter(
    (s) => s.platform === 'both' || (isAmd && s.platform === 'amd') || (isIntel && s.platform === 'intel'),
  );
}

export function groupByCategory(settings: BiosSetting[]): Record<string, BiosSetting[]> {
  const result: Record<string, BiosSetting[]> = {};
  for (const cat of biosCategories) {
    const catSettings = settings.filter((s) => s.categoryId === cat.id);
    if (catSettings.length > 0) result[cat.id] = catSettings;
  }
  return result;
}
