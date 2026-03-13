# TunedPC Discord Server — Setup Reference

## Server Info

| Field | Value |
|-------|-------|
| Server Name | TUNEDPC |
| Server ID | `1481109647510339810` |
| Bot Application ID | `1481109876464685168` |
| Bot Username | TunedPC Bot#9749 |
| Permanent Invite | `https://discord.gg/k6nWt83Bcf` |
| Token File | `Discord/discord-token.txt` (gitignored, never commit) |
| Bot Code | `Discord/bot/bot.js` |
| Config (all IDs) | `Discord/bot/config.json` |
| Bot State | `Discord/bot/bot-state.json` (tracks which setup messages have been posted) |

## Release Webhook

For automated release announcements (can be used from CI/CD or release scripts without the bot running):

```
URL: https://discord.com/api/webhooks/1481120225058357260/57kW77BhbYudOYLCYw71RsirE-1HuGUpCWk_KOtmgP7Ih3kVVUyCnqNUhVM3FRulnQfJ
```

Example usage:
```bash
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"@everyone","embeds":[{"title":"v1.0.40 Released!","description":"...","color":16711680}]}'
```

## Role IDs

| Role | ID | Color | Purpose |
|------|----|-------|---------|
| Owner | `1481117889728876544` | #FF0000 | Full admin |
| Admin | `1481117887925059645` | #CC0000 | Server management |
| Moderator | `1481117885576249429` | #FF4444 | Kick, timeout, manage messages |
| Support Team | `1481117883642806312` | #FF8888 | Manage support channels |
| Bot | `1481117881201856555` | #666666 | Admin for bot |
| Customer | `1481117879721267411` | #E03C3C | Verified app purchasers |
| Verified | `1481117877355548873` | #FFFFFF | Chat access (given via button) |
| COD | `1481120214061154390` | #FF6600 | Game role |
| Fortnite | `1481120216002855095` | #9D4DFF | Game role |
| Valorant | `1481120218271977634` | #FF4655 | Game role |
| CS2 | `1481120219983253516` | #DE9B35 | Game role |
| Arc Raiders | `1481120222357491883` | #00BFFF | Game role |

## Channel IDs

| Channel | ID | Category |
|---------|----|----------|
| #welcome | `1481400099426013314` | WELCOME & INFO |
| #rules | `1481117909932708007` | WELCOME & INFO |
| #announcements | `1481117912541561017` | WELCOME & INFO |
| #changelogs | `1481117915133775955` | WELCOME & INFO |
| #faq | `1481117917465546864` | WELCOME & INFO |
| #role-select | `1481117919986454569` | WELCOME & INFO |
| #general | `1481117922549170227` | COMMUNITY |
| #introductions | `1481117924784738355` | COMMUNITY |
| #off-topic | `1481117927137607680` | COMMUNITY |
| #clips-and-screenshots | `1481117929104740446` | COMMUNITY |
| #memes | `1481117931680301086` | COMMUNITY |
| #optimization-tips | `1481117933806551130` | GAME OPTIMIZATION |
| #share-your-results | `1481117935954300962` | GAME OPTIMIZATION |
| #windows-tweaks | `1481117938126684344` | GAME OPTIMIZATION |
| #hardware-discussion | `1481117940538675464` | GAME OPTIMIZATION |
| #cod | `1481117943030091858` | GAME CHANNELS |
| #fortnite | `1481117945391218688` | GAME CHANNELS |
| #valorant | `1481117947824050361` | GAME CHANNELS |
| #cs2 | `1481117950374051974` | GAME CHANNELS |
| #arc-raiders | `1481117953301942353` | GAME CHANNELS |
| #other-games | `1481117955688239104` | GAME CHANNELS |
| #get-tuned | `1481125880225857780` | SERVICES |
| #results | `1481125882407157780` | SERVICES |
| #reviews | `1481125885485650012` | SERVICES |
| #deals | `1481125889495269571` | SERVICES |
| #bug-reports (Forum) | `1481117957789585630` | SUPPORT |
| #feature-requests (Forum) | `1481117959970623540` | SUPPORT |
| #app-help | `1481117963028271175` | SUPPORT |
| #installation-help | `1481117965142196347` | SUPPORT |
| #mod-chat | `1481117977687363676` | STAFF ONLY |
| #mod-log | `1481117979990167692` | STAFF ONLY |
| #admin-chat | `1481117982062149746` | STAFF ONLY |
| #bot-commands | `1481117984448712794` | STAFF ONLY |

## Category IDs

| Category | ID |
|----------|-----|
| WELCOME & INFO | `1481117892215832638` |
| COMMUNITY | `1481117894460047361` |
| GAME OPTIMIZATION | `1481117897102200964` |
| GAME CHANNELS | `1481117899870572564` |
| SERVICES | `1481125877298237594` |
| SUPPORT | `1481117902756118790` |
| VOICE | `1481117905079894058` |
| STAFF ONLY | `1481117907827298465` |

## Bot Features

### Persistent Setup Messages (posted once, tracked in bot-state.json)
- **#rules**: "Get Verified" embed with green Verify Me button
- **#role-select**: "Pick Your Games" embed with 5 game role toggle buttons
- **#get-tuned**: Service description embed with "Book a Tune" link button (-> tunedpc.com/products/pc-optimization) + "Ask a Question" button (opens ticket)
- **#results**: Before/after benchmark template

### On Member Join
- Welcome DM with quick start guide, mentions #get-tuned and DISCORD15 discount
- Welcome message in #general
- Join log in #mod-log (with account age, member count)

### On Member Leave
- Leave log in #mod-log (with roles they had)

### Button Interactions
| Button | Location | Action |
|--------|----------|--------|
| Verify Me | #rules | Grants Verified role, ephemeral confirmation |
| COD/Fortnite/Valorant/CS2/Arc Raiders | #role-select | Toggles game role on/off |
| Book a Tune | #get-tuned | Link button -> `https://tunedpc.com/products/pc-optimization` |
| Ask a Question | #get-tuned | Creates private ticket channel for pre-sales questions |
| Close Ticket | ticket channels | Closes ticket, DMs owner asking for review, deletes channel after 5s |

### Slash Commands
| Command | Permission | Description |
|---------|-----------|-------------|
| `/release <version> <notes>` | Administrator | Posts release announcement to #announcements with @everyone |
| `/announce <title> <message>` | Administrator | Posts custom announcement embed |
| `/verify <user>` | Moderator | Manually grant Verified role to a user |
| `/stats` | Moderator | Server stats: member counts, game role breakdown, open tickets |
| `/close` | Moderator | Close the current ticket channel |

### Ticket System
1. User clicks "Ask a Question" in #get-tuned
2. Bot creates private `ticket-<username>` channel in SERVICES category
3. Only visible to: the user, Owner, Admin, Support Team, and the bot
4. Bot posts intake message with instructions
5. Staff or user clicks "Close Ticket" or uses `/close`
6. Bot DMs the user asking for a review in #results and #reviews
7. Channel is deleted after 5 seconds
8. All opens/closes logged in #mod-log

### AutoMod Rules (4 active)
1. **Block Spam** — Discord ML-based spam detection, alerts to #mod-log
2. **Block Mention Spam** — 5+ mentions = block + 1hr timeout, raid protection enabled
3. **Block Suspicious Links** — Regex for fake nitro, phishing, URL shorteners
4. **Profanity Filter** — Discord preset filters for profanity, slurs, sexual content

## Anti-Spam Layers
1. **Verification Level: Medium** — Account must be 5+ minutes old
2. **@everyone = read-only** — No send permissions until Verified role
3. **Verification button required** — Must click in #rules to get Verified
4. **AutoMod ML spam detection** — Catches bot patterns automatically
5. **Mention spam + raid protection** — Auto-timeout for mass mentions
6. **Slowmode** — 10s in #general, 30s-60s in support channels

## Guild Settings
- Verification Level: 2 (Medium)
- Default Notifications: Mentions only
- Content Filter: Scan all members
- System Channel: #mod-log

## App Integration
- **Discord banner** in `src/components/home/HomePage.tsx` shows after optimization completes
- Links to `https://discord.gg/k6nWt83Bcf`
- Mentions DISCORD15 discount code
- Dismissable, only shows post-optimization (not on every launch)

## Running the Bot

### Start locally
```bash
cd Discord/bot
npm start          # or: node bot.js
npm run dev        # with --watch for auto-restart on file changes
```

### For 24/7 hosting
The bot needs to run continuously. Options:
- **Railway.app** (free tier) — push Discord/bot folder
- **VPS** ($5/mo DigitalOcean/Hetzner) — use PM2: `pm2 start bot.js --name tunedpc-bot`
- **Local PC** — Windows Task Scheduler or run as a service

### Updating bot messages
If you need to re-post a setup message (e.g., after changing the #get-tuned embed):
1. Delete the old message from Discord (or via API)
2. Remove the corresponding key from `bot-state.json` (e.g., `getTunedMessageId`)
3. Restart the bot — it will re-post the missing message

### Adding a new game role
1. Create the role via Discord or API
2. Add the role ID to `config.json` under `roles`
3. Add a new ButtonBuilder to the `postRoleSelectMessage` function in `bot.js`
4. Delete `roleSelectMessageId` from `bot-state.json`
5. Restart bot

## Files Overview

```
Discord/
  discord-token.txt          # Bot token (NEVER commit)
  setup-server.js            # Initial server setup script (already ran)
  DISCORD_SETUP.md           # This file
  bot/
    bot.js                   # Main bot code
    config.json              # All role/channel/category IDs
    bot-state.json           # Tracks posted setup messages
    create-roles.js          # One-time role creation script
    create-channels.js       # One-time channel creation script
    package.json             # Node project (discord.js dependency)
    node_modules/            # Dependencies
```

## Sales Funnel Flow

```
TikTok/YouTube/Website
        |
        v
  Discord (free community)
        |
  Tips + Results + Reviews
        |
        v
  #get-tuned -> tunedpc.com/products/pc-optimization
        |
        v
  1-on-1 PC Tune (paid service)
        |
  Customer posts results -> more social proof -> cycle repeats
```

## Discount Code
- **DISCORD15** — 15% off for Discord members (mentioned in welcome DM, #get-tuned embed, and app banner)
- Must be configured on the TunedPC website/Shopify to actually apply the discount
