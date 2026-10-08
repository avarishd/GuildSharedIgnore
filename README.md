# 🛡️ GuildSharedIgnore

<p align="center">
  <img src="https://img.shields.io/badge/World%20of%20Warcraft-Legion%207.3.5-7B68EE?style=for-the-badge" alt="WoW Legion 7.3.5">
  <img src="https://img.shields.io/badge/Interface-70300-58A6FF?style=for-the-badge" alt="Interface 70300">
  <img src="https://img.shields.io/badge/Version-5.0-20C997?style=for-the-badge" alt="Version 5.0">
  <img src="https://img.shields.io/badge/License-MIT-F7DF1E?style=for-the-badge" alt="MIT License">
</p>

**A shared player-report list for World of Warcraft guilds.**

GuildSharedIgnore is made for **Legion 7.3.5 (Interface 70300)**. Guild members with the addon can share player names, categories, and notes through WoW's addon messaging. No external service is needed.

## ✨ Features

- 📝 Add, edit, search, sort, and remove player reports.
- 🔄 Sync list changes with guild members who use the addon.
- 🛡️ Filter messages from listed players, warn about them in your party or raid, automatically decline their party invitations, and confirm before inviting listed players.
- 🔴 Hide Premade Groups led by players on the shared list and applications containing listed players by default, or show matching names in red using the **Hide listed LFG players** setting. When an application is shown, listed members have their **Invite** button replaced with **Blocked by GSI**.
- 📢 Optionally announce list changes in guild chat or mute the addon's chat messages.
- 📥 Import WoW's Ignore List into a hidden **Ignore List** category.
- 🎨 Adjust the interface opacity and resize the window.
- ↩️ Undo your most recent confirmed removal during the current session.

## 📦 Install

Place the `GuildSharedIgnore` folder in:

```text
World of Warcraft/Interface/AddOns/
```

Restart or reload the UI, then enter `/gsi`.

## 🎮 Using the list

Enter a player name, choose a category, and optionally add a note, then click **ADD**. If the name field is empty, the addon uses your player target when possible.

Click a report's note to edit it. Click **×** to remove a player; confirmation can be turned on or off in Settings. **UNDO** restores the most recently removed entry, including its note and category. Undo is available only until another entry is removed or the current session ends.

Use the search field to find players by name, who added them, category, or note. Click **PLAYER**, **ADDED BY**, **CATEGORY**, or **DATE** to sort.

## ⚙️ Sync and settings

Sync starts automatically while you are in a guild and repeats every five minutes. You can also click **SYNC** or use `/gsi sync`. The interface shows sync status and the results.

Open the gear menu to:

- Set background opacity from 20% to 100%.
- Toggle guild announcements for additions, edits, and removals.
- Mute the addon's chat messages. Group warnings remain visible.
- Turn the delete confirmation on or off (on by default).
- Hide Premade Groups led by listed players and applications containing listed players (on by default; turn off to show matches in red). The Invite button remains unavailable for applications containing listed players.

Other commands:

```text
/gsi          Toggle the interface
/gsi sync     Start a sync
/gsi debug    Show sync and addon-user diagnostics
/gsi version  Show addon version information
```

## 📥 WoW Ignore List imports

GuildSharedIgnore **reads from but never changes WoW's Ignore List**. Players on that list are imported into GSI with an empty note and the hidden **Ignore List** category. If you remove a player from WoW's Ignore List, GSI removes the corresponding imported entry for the character that imported it. Manually categorized entries and imports belonging to other characters are left alone.

The importing character is recorded as the entry's author. Deleting an imported GSI entry while the player is still on WoW's Ignore List does not prevent it from being imported again later.

## 🏷️ Categories and protection

Selectable categories are **Toxic**, **Bad**, **Leaver**, **Scammer**, **AFK**, **Bad Attitude**, and **Other**. Imported Ignore List entries use a separate hidden category.

Protection checks the shared list to filter supported chat messages, warn when a listed player joins your party or raid, and decline their party invitations. These features do not add or remove players from WoW's Ignore List.

## 🧩 Compatibility

GuildSharedIgnore targets **Legion 7.3.5**. Modern Retail and Classic are not supported.

## 🐛 Reporting a problem

When opening an issue, include your WoW version, addon version, the full Lua error, what you were doing, and steps to reproduce it.

## 📜 License

Released under the [MIT License](LICENSE).
