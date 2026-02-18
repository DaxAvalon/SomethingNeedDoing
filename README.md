# Something Need Doing

[![Lint](https://github.com/a-hadley/SomethingNeedDoing/actions/workflows/lint.yml/badge.svg)](https://github.com/a-hadley/SomethingNeedDoing)
[![Release](https://img.shields.io/github/v/release/a-hadley/SomethingNeedDoing.svg?color=important)](https://github.com/a-hadley/SomethingNeedDoing/releases)
[![Issues](https://img.shields.io/github/issues/a-hadley/SomethingNeedDoing?color=blue)](https://github.com/a-hadley/SomethingNeedDoing/issues)

A guild-wide profession directory and craft request board for World of Warcraft Classic.

## Overview

Something Need Doing is a guild-first crafting coordinator built to replace the usual chaos of guild chat and whispers. Every guild member running the addon automatically shares their known recipes, building a live, searchable directory of who can craft what. Instead of asking around each time someone needs an enchant, gem, or piece of gear, members can look up crafters instantly and submit a structured request right from the directory.

Crafters see incoming demand at a glance, claim jobs, and move them through a clear lifecycle — Open, Claimed, Crafted, Delivered — so nothing falls through the cracks. Requesters get notified when their item is ready. Officers and guild masters have moderation tools to keep the board tidy.

The addon also tracks guild crafting activity over time. A built-in leaderboard ranks crafters by output across weekly, monthly, and all-time windows, and a searchable craft history log keeps a record of every completed request.

If you have **Auctionator** or **TSM** installed with recent auction data, the directory will show estimated material costs, output item values, and profit margins for each recipe — handy for pricing guild crafts or deciding what to make next.

All data syncs automatically between guild members in the background. No server, no website, no setup beyond installing the addon.

## Features

### Guild Recipe Directory
- Searchable catalog of every recipe known by guild members
- Filter by profession, crafter online status, material availability, or item rarity
- Sort by name, rarity, or item level
- See which crafters know a recipe, their skill level, and whether they're online
- View required materials, item tooltips, and cost breakdowns
- One-click whisper to a crafter or create a request directly from the directory

### Craft Request Board
- Post requests for items you need crafted
- Full lifecycle tracking: Open → Claimed → Crafted → Delivered
- Material snapshots and inline notes on every request
- Role-based permissions (requester, crafter, officer, guild master)
- Delivery notifications and audit trail of all status changes
- Offered tip field to set gold expectations for crafters
- Preferred crafter selection to direct requests to a specific guild member
- Filter by "My Requests", "My Claims", or all requests
- Search and filter by profession, status, or materials

### Statistics & Leaderboards
- Crafter performance rankings across all-time, monthly, and weekly windows
- Filter leaderboard by profession
- Searchable craft history log with item and crafter details
- Personal stats summary showing your totals and top profession

### Shared Materials
- Opt-in system for guild members to share available crafting materials
- Directory shows which crafters have materials on hand
- Material availability tracked in request details

### Auction House Pricing
- Supports both Auctionator and TSM as price sources
- Shows per-material cost, total craft cost, output item value, and estimated profit
- Prices displayed in familiar gold/silver/copper format

### Real-Time Sync
- Peer-to-peer sync across all guild members — no external server needed
- Incremental updates with full rebroadcast fallback
- Combat-aware message queuing to prevent disconnects
- Compressed messages with rate limiting

## Installation

### Manual
1. Download the latest release zip
2. Extract the `SomethingNeedDoing` folder into your WoW addons directory:
   ```
   World of Warcraft/_classic_/Interface/AddOns/SomethingNeedDoing
   ```
3. Restart WoW or reload your UI (`/reload`)

### From CurseForge
Search for **Something Need Doing** in the CurseForge app or website.

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/snd` | Toggle the main window |
| `/snd config` | Open addon settings |
| `/snd debug` | Show player/recipe counts and comms diagnostics |
| `/snd broadcast` | Manually broadcast your recipes to the guild |
| `/snd testguild` | Test guild member visibility and cache |

### Main Window Tabs

- **Directory** — Browse and search guild recipes, whisper crafters, create requests
- **Requests** — View and manage the craft request board
- **Stats** — Leaderboards and crafting analytics
- **Me** — Your professions, scan status, database stats, comms diagnostics

## Configuration

Open settings with `/snd config` or through the WoW Interface Options panel.

| Setting | Description |
|---------|-------------|
| Auto-publish on login | Broadcast your recipes when you log in |
| Auto-publish on skill change | Re-broadcast when profession skills change |
| Share materials | Opt-in to sharing your available crafting materials |
| Auto-publish materials | Automatically broadcast material changes |
| Show minimap button | Toggle the minimap icon |
| Officer rank index | Threshold for officer-level permissions |
| Debug mode | Enable detailed logging and diagnostics |

## Optional Dependencies

- **Auctionator** — Adds auction house price data to recipe tooltips
- **TradeSkillMaster (TSM)** — Alternative price source using DBMarket valuations

## Architecture

```
SomethingNeedDoing/
├── Core.lua              # Initialization, event handling
├── DB.lua                # Database schema, migrations, persistence
├── Utils.lua             # Helpers (player keys, timestamps, hashing)
├── Locale.lua            # Localization strings
├── Comms.lua             # Guild communication, serialization, compression
├── Scanner.lua           # Profession scanning, recipe detection
├── Roster.lua            # Guild member tracking, role determination
├── Options.lua           # Settings panel (AceConfig)
├── Minimap.lua           # Minimap button (LibDBIcon)
├── UI.lua                # Main window, tab management
├── modules/
│   ├── ItemCache.lua     # Async item data loading
│   ├── RecipeData.lua    # Recipe output item resolution
│   ├── RecipeSearch.lua  # Search and filtering
│   ├── DirectoryUI.lua   # Directory tab rendering
│   └── AuctionPrice.lua  # Price source integration
├── requests/
│   ├── RequestCore.lua   # Request CRUD, lifecycle, permissions
│   └── RequestUI.lua     # Request board rendering
├── stats/
│   ├── StatsCore.lua     # Craft log, statistics aggregation
│   └── StatsUI.lua       # Analytics panel rendering
└── libs/                 # External libraries (pulled by CurseForge packager)
    ├── Ace3/             # AceAddon, AceEvent, AceComm, AceDB, AceGUI, etc.
    ├── LibDBIcon-1.0/    # Minimap button support
    ├── LibDeflate/       # Message compression
    └── LibSharedMedia-3.0/
```

## Development

### Prerequisites

- [Luacheck](https://github.com/mpeterv/luacheck) for linting (`luarocks install luacheck`)
- `zip` for packaging

### Local Development

```bash
# Run all checks (lint + package validation)
make check

# Lint only
make lint

# Build distributable zip
make package

# Clean build artifacts
make clean
```

### CI

GitHub Actions runs luacheck and package validation on every push and pull request to `master`. See [.github/workflows/lint.yml](.github/workflows/lint.yml).

### CurseForge Deployment

Releases are deployed to CurseForge automatically via webhook when commits are pushed to GitHub.

**Setup:**
1. Create an API token at your [CurseForge API tokens page](https://wow.curseforge.com/account/api-tokens)
2. Find your project ID on the CurseForge project Overview page
3. Add a webhook in your GitHub repo under **Settings → Webhooks**:
   ```
   https://www.curseforge.com/api/projects/{projectID}/package?token={token}
   ```
4. Leave all other webhook settings at defaults

**Release types are determined by git tags:**
- Tagged with `alpha` in the name → Alpha release
- Tagged with `beta` in the name → Beta release
- Other tags (e.g. `v0.5.0`) → Full release
- Untagged commits → Alpha

The `.pkgmeta` file configures what gets packaged and how external libraries are fetched.

### Packaging a Release

```bash
# Tag and push
git tag v0.6.0
git push origin v0.6.0
```

The CurseForge webhook picks up the tag push and builds the release automatically.

## Version

**Current:** 0.6.0
**WoW Interface:** 20504, 20505 (Classic)
**Author:** Ariailis-Dreamscythe &lt;All Gear No Fear&gt;

## License

All rights reserved.
