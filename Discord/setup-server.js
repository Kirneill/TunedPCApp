const fs = require('fs');
const TOKEN = fs.readFileSync(__dirname + '/discord-token.txt', 'utf8').trim();
const GUILD_ID = '1481109647510339810';
const API = 'https://discord.com/api/v10';

async function api(method, endpoint, data) {
  const options = {
    method,
    headers: {
      'Authorization': `Bot ${TOKEN}`,
      'Content-Type': 'application/json',
    },
  };
  if (data) options.body = JSON.stringify(data);
  const res = await fetch(`${API}${endpoint}`, options);

  // Handle rate limiting
  if (res.status === 429) {
    const body = await res.json();
    const wait = (body.retry_after || 1) * 1000 + 200;
    console.log(`  Rate limited, waiting ${Math.round(wait)}ms...`);
    await sleep(wait);
    return api(method, endpoint, data); // retry
  }

  const remaining = res.headers.get('x-ratelimit-remaining');
  if (remaining === '0') {
    const resetAfter = parseFloat(res.headers.get('x-ratelimit-reset-after') || '1');
    await sleep(resetAfter * 1000 + 200);
  }

  if (!res.ok) {
    const text = await res.text();
    console.error(`ERROR ${method} ${endpoint}: ${res.status} ${text}`);
    return null;
  }
  if (res.status === 204) return {};
  return res.json();
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  console.log('=== Step 1: Verify Guild ===');
  const guild = await api('GET', `/guilds/${GUILD_ID}`);
  if (!guild) { console.error('Cannot access guild. Check bot token and permissions.'); process.exit(1); }
  console.log(`Guild: ${guild.name} (ID: ${guild.id})`);

  // Clean up default channels
  console.log('\n=== Step 2: Clean Up Default Channels ===');
  const existingChannels = await api('GET', `/guilds/${GUILD_ID}/channels`);
  if (existingChannels) {
    for (const ch of existingChannels) {
      console.log(`  Deleting default channel: ${ch.name} (${ch.id})`);
      await api('DELETE', `/channels/${ch.id}`);
      await sleep(300);
    }
  }

  // --- ROLES ---
  console.log('\n=== Step 3: Modify @everyone (read-only) ===');
  // VIEW_CHANNEL(1024) + READ_MESSAGE_HISTORY(65536) + ADD_REACTIONS(64) + CONNECT(1048576) + USE_APPLICATION_COMMANDS(2147483648) = 2148598848
  await api('PATCH', `/guilds/${GUILD_ID}/roles/${GUILD_ID}`, { permissions: '2148598848' });
  console.log('@everyone set to read-only');

  console.log('\n=== Step 4: Create Roles ===');

  const verified = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Verified', permissions: '311422209600', color: 0xFFFFFF, hoist: false, mentionable: false
  });
  console.log(`  Verified: ${verified?.id}`);
  await sleep(300);

  const customer = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Customer', permissions: '311422209600', color: 0xE03C3C, hoist: true, mentionable: false
  });
  console.log(`  Customer: ${customer?.id}`);
  await sleep(300);

  const botRole = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Bot', permissions: '8', color: 0x666666, hoist: false, mentionable: false
  });
  console.log(`  Bot: ${botRole?.id}`);
  await sleep(300);

  const support = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Support Team', permissions: '328602086976', color: 0xFF8888, hoist: true, mentionable: true
  });
  console.log(`  Support Team: ${support?.id}`);
  await sleep(300);

  const moderator = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Moderator', permissions: '1428113845826', color: 0xFF4444, hoist: true, mentionable: true
  });
  console.log(`  Moderator: ${moderator?.id}`);
  await sleep(300);

  const admin = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Admin', permissions: '1428382281334', color: 0xCC0000, hoist: true, mentionable: true
  });
  console.log(`  Admin: ${admin?.id}`);
  await sleep(300);

  const owner = await api('POST', `/guilds/${GUILD_ID}/roles`, {
    name: 'Owner', permissions: '8', color: 0xFF0000, hoist: true, mentionable: false
  });
  console.log(`  Owner: ${owner?.id}`);
  await sleep(300);

  // Reorder roles
  console.log('\n=== Step 5: Reorder Roles ===');
  await api('PATCH', `/guilds/${GUILD_ID}/roles`, [
    { id: owner.id, position: 7 },
    { id: admin.id, position: 6 },
    { id: moderator.id, position: 5 },
    { id: support.id, position: 4 },
    { id: botRole.id, position: 3 },
    { id: customer.id, position: 2 },
    { id: verified.id, position: 1 },
  ]);
  console.log('Roles reordered');

  // --- CATEGORIES ---
  console.log('\n=== Step 6: Create Categories ===');

  // Read-only info category: @everyone can view but not send, Verified also cannot send
  const catInfo = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'WELCOME & INFO', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '2048', allow: '0' },
    ]
  });
  console.log(`  WELCOME & INFO: ${catInfo?.id}`);
  await sleep(400);

  // Community: @everyone denied send, Verified can send
  const catComm = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'COMMUNITY', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '2048', allow: '0' },
      { id: verified.id, type: 0, allow: '2048', deny: '0' },
      { id: customer.id, type: 0, allow: '2048', deny: '0' },
    ]
  });
  console.log(`  COMMUNITY: ${catComm?.id}`);
  await sleep(400);

  const catOpt = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'GAME OPTIMIZATION', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '2048', allow: '0' },
      { id: verified.id, type: 0, allow: '2048', deny: '0' },
      { id: customer.id, type: 0, allow: '2048', deny: '0' },
    ]
  });
  console.log(`  GAME OPTIMIZATION: ${catOpt?.id}`);
  await sleep(400);

  const catGames = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'GAME CHANNELS', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '2048', allow: '0' },
      { id: verified.id, type: 0, allow: '2048', deny: '0' },
      { id: customer.id, type: 0, allow: '2048', deny: '0' },
    ]
  });
  console.log(`  GAME CHANNELS: ${catGames?.id}`);
  await sleep(400);

  const catSupport = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'SUPPORT', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '2048', allow: '0' },
      { id: verified.id, type: 0, allow: '2048', deny: '0' },
      { id: customer.id, type: 0, allow: '2048', deny: '0' },
    ]
  });
  console.log(`  SUPPORT: ${catSupport?.id}`);
  await sleep(400);

  const catVoice = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'VOICE', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, allow: '1048576', deny: '0' },
      { id: verified.id, type: 0, allow: '2097664', deny: '0' },  // SPEAK + STREAM
      { id: customer.id, type: 0, allow: '2097664', deny: '0' },
    ]
  });
  console.log(`  VOICE: ${catVoice?.id}`);
  await sleep(400);

  // Staff only: hide from everyone, show to mods+
  const catStaff = await api('POST', `/guilds/${GUILD_ID}/channels`, {
    name: 'STAFF ONLY', type: 4,
    permission_overwrites: [
      { id: GUILD_ID, type: 0, deny: '1024', allow: '0' },           // @everyone: no view
      { id: moderator.id, type: 0, allow: '3072', deny: '0' },       // VIEW + SEND
      { id: admin.id, type: 0, allow: '3072', deny: '0' },
      { id: owner.id, type: 0, allow: '3072', deny: '0' },
      { id: support.id, type: 0, allow: '3072', deny: '0' },
      { id: botRole.id, type: 0, allow: '3072', deny: '0' },
    ]
  });
  console.log(`  STAFF ONLY: ${catStaff?.id}`);
  await sleep(400);

  // --- CHANNELS ---
  console.log('\n=== Step 7: Create Channels ===');

  // Helper for quick channel creation
  async function createText(name, parentId, topic, opts = {}) {
    const data = { name, type: 0, parent_id: parentId, topic, ...opts };
    const ch = await api('POST', `/guilds/${GUILD_ID}/channels`, data);
    console.log(`  #${name}: ${ch?.id}`);
    await sleep(350);
    return ch;
  }

  async function createVoice(name, parentId) {
    const ch = await api('POST', `/guilds/${GUILD_ID}/channels`, { name, type: 2, parent_id: parentId });
    console.log(`  ${name}: ${ch?.id}`);
    await sleep(350);
    return ch;
  }

  async function createForum(name, parentId, topic, tags) {
    const ch = await api('POST', `/guilds/${GUILD_ID}/channels`, {
      name, type: 15, parent_id: parentId, topic,
      available_tags: tags,
      default_forum_layout: 1, // List view
    });
    console.log(`  #${name} (Forum): ${ch?.id}`);
    await sleep(350);
    return ch;
  }

  // --- WELCOME & INFO (read-only for everyone) ---
  const rulesCh = await createText('rules', catInfo.id, 'Server rules -- read before participating');
  const announceCh = await createText('announcements', catInfo.id, 'Official SENSEQUALITY and TunedPC announcements');
  await createText('changelogs', catInfo.id, 'App version history and patch notes');
  await createText('faq', catInfo.id, 'Frequently asked questions about SENSEQUALITY');
  await createText('role-select', catInfo.id, 'Pick your game roles here');

  // --- COMMUNITY ---
  await createText('general', catComm.id, 'General discussion about gaming and PC optimization', { rate_limit_per_user: 10 });
  await createText('introductions', catComm.id, 'Introduce yourself and share your PC setup', { rate_limit_per_user: 60 });
  await createText('off-topic', catComm.id, 'Anything goes (within reason)');
  await createText('clips-and-screenshots', catComm.id, 'Share your gameplay clips and screenshots');
  await createText('memes', catComm.id, 'Gaming and PC memes');

  // --- GAME OPTIMIZATION ---
  await createText('optimization-tips', catOpt.id, 'Share and discuss PC optimization techniques');
  await createText('share-your-results', catOpt.id, 'Post your before/after benchmarks and FPS improvements');
  await createText('windows-tweaks', catOpt.id, 'Windows optimization discussion and tips');
  await createText('hardware-discussion', catOpt.id, 'CPUs, GPUs, RAM, monitors -- talk hardware here');

  // --- GAME CHANNELS ---
  await createText('cod', catGames.id, 'Call of Duty settings, optimization, and discussion');
  await createText('fortnite', catGames.id, 'Fortnite settings, optimization, and discussion');
  await createText('valorant', catGames.id, 'Valorant settings, optimization, and discussion');
  await createText('cs2', catGames.id, 'Counter-Strike 2 settings, optimization, and discussion');
  await createText('arc-raiders', catGames.id, 'Arc Raiders settings, optimization, and discussion');
  await createText('other-games', catGames.id, 'Discussion for games not listed above');

  // --- SUPPORT ---
  await createForum('bug-reports', catSupport.id, 'Report bugs with SENSEQUALITY Optimizer', [
    { name: 'Bug', moderated: false },
    { name: 'Crash', moderated: false },
    { name: 'Visual Glitch', moderated: false },
    { name: 'Performance', moderated: false },
    { name: 'Installation', moderated: false },
    { name: 'Resolved', moderated: true },
  ]);
  await createForum('feature-requests', catSupport.id, 'Suggest new features or improvements', [
    { name: 'New Game', moderated: false },
    { name: 'UI/UX', moderated: false },
    { name: 'Windows Tweak', moderated: false },
    { name: 'BIOS', moderated: false },
    { name: 'Other', moderated: false },
    { name: 'Implemented', moderated: true },
  ]);
  await createText('app-help', catSupport.id, 'Get help using SENSEQUALITY Optimizer', { rate_limit_per_user: 30 });
  await createText('installation-help', catSupport.id, 'Help with installing and setting up the app', { rate_limit_per_user: 30 });

  // --- VOICE ---
  await createVoice('General Voice', catVoice.id);
  await createVoice('Gaming Session 1', catVoice.id);
  await createVoice('Gaming Session 2', catVoice.id);
  await createVoice('Support Voice', catVoice.id);

  // --- STAFF ONLY ---
  await createText('mod-chat', catStaff.id, 'Moderator discussion');
  const modLog = await createText('mod-log', catStaff.id, 'AutoMod and moderation action logs');
  await createText('admin-chat', catStaff.id, 'Admin-only discussion');
  await createText('bot-commands', catStaff.id, 'Bot testing and commands');

  // --- GUILD SETTINGS ---
  console.log('\n=== Step 8: Guild Settings ===');
  await api('PATCH', `/guilds/${GUILD_ID}`, {
    verification_level: 2,                   // Medium: must be registered 5+ min
    default_message_notifications: 1,        // Only @mentions
    explicit_content_filter: 2,              // Scan messages from all members
    system_channel_id: modLog.id,             // System messages (raid alerts, joins) go to mod-log
  });
  console.log('Guild settings updated');

  // --- AUTOMOD ---
  console.log('\n=== Step 9: AutoMod Rules ===');

  // Block spam (ML-based)
  await api('POST', `/guilds/${GUILD_ID}/auto-moderation/rules`, {
    name: 'Block Spam',
    event_type: 1,  // MESSAGE_SEND
    trigger_type: 3, // SPAM
    actions: [
      { type: 1 },  // Block message
      { type: 2, metadata: { channel_id: modLog.id } },  // Alert to mod-log
    ],
    enabled: true,
  });
  console.log('  Block Spam rule created');
  await sleep(500);

  // Block mention spam with raid protection
  await api('POST', `/guilds/${GUILD_ID}/auto-moderation/rules`, {
    name: 'Block Mention Spam',
    event_type: 1,
    trigger_type: 5, // MENTION_SPAM
    trigger_metadata: {
      mention_total_limit: 5,
      mention_raid_protection_enabled: true,
    },
    actions: [
      { type: 1 },  // Block
      { type: 2, metadata: { channel_id: modLog.id } },  // Alert
      { type: 3, metadata: { duration_seconds: 3600 } },  // Timeout 1 hour
    ],
    enabled: true,
  });
  console.log('  Block Mention Spam rule created');
  await sleep(500);

  // Block suspicious links (fake nitro, phishing)
  await api('POST', `/guilds/${GUILD_ID}/auto-moderation/rules`, {
    name: 'Block Suspicious Links',
    event_type: 1,
    trigger_type: 1, // KEYWORD
    trigger_metadata: {
      regex_patterns: [
        '(discord\\.gift|discordapp\\.com/gifts)',
        '(free\\s*nitro|steam\\s*gift)',
        '(bit\\.ly|tinyurl\\.com|shorte\\.st|adf\\.ly)',
      ],
    },
    actions: [
      { type: 1 },
      { type: 2, metadata: { channel_id: modLog.id } },
    ],
    enabled: true,
  });
  console.log('  Block Suspicious Links rule created');
  await sleep(500);

  // Profanity filter (Discord presets: profanity, slurs, sexual content)
  await api('POST', `/guilds/${GUILD_ID}/auto-moderation/rules`, {
    name: 'Profanity Filter',
    event_type: 1,
    trigger_type: 4, // KEYWORD_PRESET
    trigger_metadata: {
      presets: [1, 2, 3],  // Profanity, Sexual Content, Slurs
    },
    actions: [
      { type: 1 },
      { type: 2, metadata: { channel_id: modLog.id } },
    ],
    enabled: true,
  });
  console.log('  Profanity Filter rule created');

  // --- POST RULES MESSAGE ---
  console.log('\n=== Step 10: Post Rules Message ===');
  await api('POST', `/channels/${rulesCh.id}/messages`, {
    embeds: [{
      title: 'SENSEQUALITY Community Rules',
      description: [
        '**Welcome to the SENSEQUALITY & TunedPC community!**\n',
        'Please follow these rules to keep this a great place for everyone:\n',
        '**1.** Be respectful to all members. No harassment, hate speech, or personal attacks.',
        '**2.** No spam, self-promotion, or unauthorized advertising.',
        '**3.** Keep discussions relevant to the channel topic.',
        '**4.** No cheats, exploits, hacks, or piracy discussion.',
        '**5.** Use the support channels for app issues -- don\'t DM staff directly.',
        '**6.** No NSFW content of any kind.',
        '**7.** Follow Discord\'s [Terms of Service](https://discord.com/terms) and [Community Guidelines](https://discord.com/guidelines).',
        '\n*Breaking these rules may result in a warning, timeout, or ban.*',
      ].join('\n'),
      color: 0xFF0000,  // Red to match branding
      footer: { text: 'SENSEQUALITY Optimizer by TunedPC' },
    }],
  });
  console.log('Rules message posted');

  // Post welcome message in announcements
  await api('POST', `/channels/${announceCh.id}/messages`, {
    embeds: [{
      title: 'Welcome to SENSEQUALITY',
      description: [
        'Welcome to the official **SENSEQUALITY Optimizer** community by **TunedPC**!\n',
        'We\'re a community of competitive FPS gamers and PC enthusiasts focused on getting the most performance out of your hardware.\n',
        '**What is SENSEQUALITY?**',
        'A desktop app that automatically optimizes your PC and game settings for competitive FPS gaming. Supports COD, Fortnite, Valorant, CS2, Arc Raiders, and more.\n',
        '**Get Started:**',
        '> Head to <#' + rulesCh.id + '> to read the rules',
        '> Introduce yourself in the community channels',
        '> Ask for help in the support channels',
        '> Share your optimization results!\n',
        '**Download:** [sensequality.com](https://sensequality.com/products/pc-optimization)',
      ].join('\n'),
      color: 0xFF0000,
      thumbnail: { url: 'https://raw.githubusercontent.com/Kirneill/TunedPCApp/main/resources/icon.png' },
      footer: { text: 'SENSEQUALITY Optimizer by TunedPC' },
    }],
  });
  console.log('Welcome announcement posted');

  // --- SUMMARY ---
  console.log('\n========================================');
  console.log('  DISCORD SERVER SETUP COMPLETE!');
  console.log('========================================');
  console.log('\nRoles created:');
  console.log(`  Owner:        ${owner.id}`);
  console.log(`  Admin:        ${admin.id}`);
  console.log(`  Moderator:    ${moderator.id}`);
  console.log(`  Support Team: ${support.id}`);
  console.log(`  Bot:          ${botRole.id}`);
  console.log(`  Customer:     ${customer.id}`);
  console.log(`  Verified:     ${verified.id}`);
  console.log('\nCategories: 7 | Channels: ~30 | AutoMod Rules: 4');
  console.log('\nManual steps remaining:');
  console.log('  1. Enable Community: Server Settings > Enable Community');
  console.log('  2. Set up Rules Screening: Server Settings > Safety Setup');
  console.log('  3. Assign yourself the Owner role');
  console.log(`     Run: Right-click yourself > Roles > Owner`);
}

main().catch(err => {
  console.error('FATAL:', err.message);
  process.exit(1);
});
