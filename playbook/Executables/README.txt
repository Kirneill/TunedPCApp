TUNEDPC Lightweight OS Playbook
================================

Version: 1.0.0
Created by: TUNEDPC / SENSEQUALITY

Requirements:
- Windows 10 22H2 or Windows 11 22H2+
- AME Wizard (download from ameliorated.io)
- Internet connection (for component cleanup)
- Plugged in (laptop users)
- Windows Defender temporarily disabled (AME Wizard will prompt you -- re-enabled after unless you opt to remove it)
- No pending Windows updates

Instructions:
1. Download AME Wizard from https://ameliorated.io
2. Open AME Wizard
3. Drag and drop this .apbx file into AME Wizard
4. Follow the on-screen prompts
5. Choose your optimization level:
   - Recommended: Anti-cheat safe, best for online competitive games
   - Maximum Performance: More aggressive, may affect some anti-cheat
6. Select additional options (bloatware removal, telemetry, etc.)
7. Wait for the process to complete (15-45 minutes depending on hardware and selected options)
8. Reboot when prompted

WARNING: This playbook makes significant changes to Windows.
Some changes (especially WinSxS component removal) are difficult
to reverse without a clean reinstall. Create a full system backup
or system image before proceeding.

What This Playbook Does:
- Configures 55+ unnecessary Windows services (disabled or set to Manual)
- Removes 40+ bloatware AppX packages
- Disables 30 telemetry and diagnostic scheduled tasks
- Removes unused Windows capabilities (IE, Fax, WordPad, etc.)
- Applies gaming performance registry tweaks (MMCSS, scheduling, GPU)
- Hardens privacy settings and blocks telemetry hosts
- Optimizes NTFS, network, memory, and power settings
- Cleans component store, temp files, and update cache
- Activates Ultimate Performance power plan
- Disables mouse acceleration
- Removes Bing search from Start Menu
- Restores classic right-click context menu (Windows 11)

Anti-Cheat Compatibility (Recommended mode):
- Valorant (Vanguard):    SAFE
- Call of Duty (RICOCHET): SAFE
- Fortnite (EAC):         SAFE
- CS2 (VAC):              SAFE
- Tarkov (BattlEye):      SAFE
- Rainbow Six Siege:       SAFE

Note: The above applies to Recommended mode. Maximum Performance mode
disables CPU security mitigations which may trigger anti-cheat in
Valorant (Vanguard).

What is NOT touched (anti-cheat requirements):
- Secure Boot
- TPM 2.0
- HVCI / VBS / Memory Integrity
- Windows Defender (unless you opt to remove it)
- Cryptographic Services (CryptSvc)
- Windows Management Instrumentation (WMI)
- Windows Event Log
- Base Filtering Engine / Windows Firewall
- Core system services (RPC, DCOM, Audio, Network)

For game-specific config file optimization (Valorant, COD, Fortnite,
CS2, Tarkov, Rust, R6 Siege), download the SENSEQUALITY Optimizer:
https://sensequality.com

Support:
- Website: https://sensequality.com
- GitHub: https://github.com/Kirneill/TunedPCApp
- Discord: https://discord.gg/tunedpc
