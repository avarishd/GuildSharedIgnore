# 🛡️ GuildSharedIgnore

### Guild-wide shared ignore list for World of Warcraft: Legion 7.3.5

<p align="center">
  <strong>One ignore list. One guild. Everyone stays informed.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/World%20of%20Warcraft-Legion%207.3.5-7B68EE?style=for-the-badge" alt="WoW Legion 7.3.5">
  <img src="https://img.shields.io/badge/Interface-70300-58A6FF?style=for-the-badge" alt="Interface 70300">
  <img src="https://img.shields.io/badge/Version-3.2-20C997?style=for-the-badge" alt="Version 3.2">
  <img src="https://img.shields.io/badge/License-MIT-F7DF1E?style=for-the-badge" alt="MIT License">
</p>

---

## ✨ What is GuildSharedIgnore?

**GuildSharedIgnore** is a World of Warcraft addon designed for **Legion 7.3.5** that creates a shared ignore list for your guild.

Normally, every character has their own individual ignore list. GuildSharedIgnore allows guild members running the addon to **share ignored players, notes, and updates automatically** through WoW's addon communication system.

No external server or database is required.

> **If one guild member adds someone to the shared ignore list, everyone running GuildSharedIgnore can receive the entry.**

---

## 🚀 Features

<table>
<tr>
<td width="50%">

### 🔴 Shared Ignore List

* Guild-wide player list
* Automatic synchronization
* Persistent saved data
* Add and remove players
* Import from Blizzard's ignore list

</td>
<td width="50%">

### 📝 Notes

* Add notes to ignored players
* Edit notes at any time
* Notes synchronize between guild members
* 255-character note limit

</td>
</tr>

<tr>
<td>

### 🔍 Search & Sorting

Search by:

* Player name
* Added by
* Note

Sort by:

* Player A-Z / Z-A
* Added By A-Z / Z-A
* Date oldest / newest

</td>
<td>

### 🛡️ Protection

* Chat filtering
* Group warnings
* Party / raid detection
* Invite blocking
* Ignored player detection

</td>
</tr>

<tr>
<td>

### 📢 Guild Announcements

Optional `[GSI]` announcements when:

* A player is added
* A player is removed
* A note is updated

</td>
<td>

### 🖥️ Modern UI

* Dark interface
* Class-colored player names
* Resizable window
* Search field
* Editable notes
* Keyboard support

</td>
</tr>
</table>

---

# 📸 Interface

> Screenshots coming soon.

The interface provides a single overview of the entire shared list:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ GSI  v3.2                                                     ×     │
├──────────────────────────────────────────────────────────────────────┤
│ [Player name]   [Note]            [ ADD ]      [Search...] [SYNC]   │
│                                                        ✓ Announce    │
├──────────────────────────────────────────────────────────────────────┤
│ > PLAYER <       ADDED BY             NOTE              DATE         │
├──────────────────────────────────────────────────────────────────────┤
│ Avarishd         Turanius             Toxic player      04/10/26     │
│ SomePlayer       Byfar                Avoid             03/10/26     │
│ AnotherPlayer    Avarishd             —                 01/10/26     │
├──────────────────────────────────────────────────────────────────────┤
│ GuildSharedIgnore • Avarishd              YOU: 2   TOTAL: 3         │
└──────────────────────────────────────────────────────────────────────┘
```

---

# 🎮 Usage

## Open the interface

Type:

```text
/gsi
```

or create a macro:

```lua
/run SlashCmdList["GSI"]()
```

---

## ➕ Add a player

Enter the player's name:

```text
Player name: SomePlayer
Note: Avoid this player
```

Then click **ADD** or press **Enter**.

If the Player Name field is empty, GuildSharedIgnore can use your current target.

---

## 📝 Edit a note

Click the **NOTE** column for an existing player.

An editor will open where you can modify the note.

```text
┌──────────────────────────────────────┐
│ EDIT NOTE                SomePlayer  │
├──────────────────────────────────────┤
│ [ Avoid this player...             ] │
│                                      │
│                    [ CANCEL ] [ SAVE ]│
└──────────────────────────────────────┘
```

---

## ❌ Remove a player

Click the **×** button at the right side of the player's row.

The removal is then synchronized with the guild.

---

## 🔄 Synchronize

Click **SYNC** to request the latest shared ignore data from guild members.

Synchronization happens through WoW's addon communication system.

---

# 🔎 Search

The search field can match:

```text
Player name
Added by
Note
```

For example:

```text
Search: toxic
```

will find entries where `toxic` appears in the player's name, the person who added them, or their note.

---

# ↕️ Sorting

Click the column headers to change sorting.

### Player

```text
> PLAYER <
```

A-Z

Click again:

```text
< PLAYER >
```

Z-A

The same system is available for:

* **ADDED BY**
* **DATE**

---

# 📡 Communication

GuildSharedIgnore communicates through WoW's addon messaging system.

### Addon prefix

```text
GSIgnore
```

### Message types

| Type | Purpose                 |
| :--: | ----------------------- |
|  `A` | Add player              |
|  `R` | Remove player           |
|  `N` | Update note             |
|  `Q` | Request synchronization |
|  `S` | Synchronization data    |
|  `E` | End synchronization     |

No external service is required.

---

# 💾 Saved Data

GuildSharedIgnore uses:

```text
GuildSharedIgnoreDB
```

The shared player database is stored under:

```lua
GuildSharedIgnoreDB.players
```

Data persists between game sessions.

---

# 📁 Installation

Download the repository and place the addon folder inside:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── GuildSharedIgnore/
```

The folder should contain:

```text
GuildSharedIgnore/
├── GuildSharedIgnore.toc
├── GuildSharedIgnore.lua
└── GuildSharedIgnore_GUI.lua
```

Restart the game or reload your UI.

Then use:

```text
/gsi
```

---

# 🧩 Compatibility

| World of Warcraft Version |            Status           |
| :------------------------ | :-------------------------: |
| **Legion 7.3.5**          |         ✅ Supported         |
| Legion 7.0–7.3            | ⚠️ Not officially supported |
| Modern Retail             |       ❌ Not supported       |
| Classic                   |       ❌ Not supported       |

> GuildSharedIgnore targets the **Legion 7.3.5 API (`70300`)**.

---

# 🛠️ Project Structure

```text
GuildSharedIgnore/
│
├── 📄 GuildSharedIgnore.toc
│
├── 📜 GuildSharedIgnore.lua
│   ├── Shared database
│   ├── Add / remove logic
│   ├── Synchronization
│   ├── Chat filtering
│   ├── Group detection
│   └── Guild communication
│
├── 📜 GuildSharedIgnore_GUI.lua
│   ├── Main interface
│   ├── Search
│   ├── Sorting
│   ├── Notes
│   └── Resizable UI
│
├── 📄 LICENSE
└── 📖 README.md
```

---

# 🐛 Bug Reports

Found a bug?

Please open an issue and include:

* WoW version
* GuildSharedIgnore version
* Lua error message
* Full error stack
* What you were doing when the error occurred
* Steps to reproduce the problem

Example:

```text
Version: 3.2
WoW: Legion 7.3.5

Error:
GuildSharedIgnore_GUI.lua:123
attempt to index field 'foo' (a nil value)

Steps:
1. Open /gsi
2. Click NOTE
3. Click SAVE
4. Error occurs
```

---

# 💡 Feature Requests

Have an idea?

Open an issue describing:

1. What you want added
2. How it should work
3. Why it would be useful

Pull requests are also welcome.

---

# 📜 License

GuildSharedIgnore is released under the **MIT License**.

You are free to:

* ✅ Use the addon
* ✅ Modify the addon
* ✅ Fork the project
* ✅ Redistribute it
* ✅ Create derivative versions

See [`LICENSE`](LICENSE) for the complete license.

---

# 👤 Author

<p align="center">

### Avarishd

**GuildSharedIgnore**

World of Warcraft · Legion 7.3.5

</p>

---

<p align="center">
  <sub>Made for guilds that prefer to know who to avoid.</sub>
</p>
