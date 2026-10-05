# GuildSharedIgnore

<p align="center">
  <strong>One ignore list. One guild. Everyone stays informed.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/World%20of%20Warcraft-Legion%207.3.5-7B68EE?style=for-the-badge" alt="WoW Legion 7.3.5">
  <img src="https://img.shields.io/badge/Interface-70300-58A6FF?style=for-the-badge" alt="Interface 70300">
  <img src="https://img.shields.io/badge/Version-4.0-20C997?style=for-the-badge" alt="Version 4.0">
  <img src="https://img.shields.io/badge/License-MIT-F7DF1E?style=for-the-badge" alt="MIT License">
</p>

---

## ✨ What is GuildSharedIgnore?

**GuildSharedIgnore** is a World of Warcraft addon for **Legion 7.3.5** that provides a shared ignore and player-report list for guild members.

Instead of maintaining completely separate lists, guild members running GuildSharedIgnore can share:

* Ignored players
* Categories
* Notes / reports
* Additions and removals
* Updates to existing entries

Synchronization is handled entirely through **World of Warcraft's addon communication system**.

**No external server, database, or website is required.**

When one guild member adds or updates an entry, other guild members running the addon can receive the change automatically.

---

# 🚀 Features

<table>
<tr>
<td width="50%">

### 🔴 Shared Player List

* Guild-wide shared player database
* Add and remove players
* Automatic synchronization
* Manual synchronization
* Incremental synchronization
* Persistent saved data
* Conflict resolution using timestamps
* Deletion tracking

</td>
<td width="50%">

### 📝 Reports & Notes

* Add a report when adding a player
* Edit reports at any time
* 255-character note limit
* Notes synchronize between guild members
* Category can be changed while editing
* Existing reports can be updated without re-adding the player

</td>
</tr>

<tr>
<td>

### 🏷️ Categories

Entries can be classified as:

* **Toxic**
* **Bad**
* **Leaver**
* **Scammer**
* **AFK**
* **Bad Attitude**
* **Other**

Categories are synchronized together with player entries and reports.

</td>
<td>

### 🔍 Search & Sorting

Search the shared list using:

* Player name
* Added by
* Note

Sort by:

* Player
* Added By
* Category
* Date

Click a column header to switch between ascending and descending order.

</td>
</tr>

<tr>
<td>

### 🛡️ Automatic Protection

GuildSharedIgnore can:

* Filter chat messages from ignored players
* Warn when an ignored player joins your party
* Warn when an ignored player joins your raid
* Automatically decline party invitations from ignored players

</td>
<td>

### 📢 Guild Announcements

Optional `[GSI]` guild announcements can be enabled for:

* Player additions
* Player removals

Announcements can include:

* Player name
* Category
* Report / note
* Person who performed the action

</td>
</tr>

<tr>
<td>

### 🔄 Automatic Synchronization

* Syncs automatically when entering the world
* Automatically syncs while in a guild
* Periodic automatic synchronization
* Manual **SYNC** button
* Incremental synchronization after the first sync
* Sync status displayed in the interface
* Reports number of responders and changes received

</td>
<td>

### 🖥️ Interface

* Dark themed interface
* Class-colored player names
* Class-colored guild member names
* Colored categories
* Alternating table rows
* Search field
* Category selector
* Editable reports
* Resizable window
* Keyboard support
* Sync status display
* Addon version display
* Guild addon-user/version information

</td>
</tr>
</table>

---

# 📸 Interface

<img width="850" alt="GuildSharedIgnore interface" src="https://i.imgur.com/mwAsYGp.png"/>

The interface displays:

| Column       | Description                                  |
| :----------- | :------------------------------------------- |
| **PLAYER**   | Player on the shared list                    |
| **ADDED BY** | Guild member who originally added the player |
| **CATEGORY** | Report category                              |
| **NOTE**     | Report / additional information              |
| **DATE**     | Date and time of the latest entry update     |
| **×**        | Remove the player from the shared list       |

The bottom of the interface also shows:

* Your number of entries
* Total number of entries
* Addon author
* GitHub repository
* Current synchronization state

---

# 🎮 Usage

## Open the interface

Type:

```text
/gsi
```

The addon interface will open.

You can also create a macro:

```lua
/run SlashCmdList["GUILDSHAREDIGNORE"]()
```

---

## ➕ Add a player

Enter the player's name in the **Player** field.

Optionally select a category and enter a report:

```text
Player:   SomePlayer
Category: Toxic
Note:     Repeatedly griefed the group
```

Then click **ADD** or press **Enter**.

### Add your current target

If the **Player** field is empty, GuildSharedIgnore checks your current target.

If your target is a player, the target's name is automatically used.

This makes it possible to:

1. Target a player
2. Leave the Player field empty
3. Select a category
4. Enter a note
5. Press **ADD**

---

# 🏷️ Categories

The category selector is available beside the player field.

Current categories:

```text
Toxic
Bad
Leaver
Scammer
AFK
Bad Attitude
Other
```

Categories are displayed with different colors in the player list.

Categories are also synchronized with the rest of the entry.

---

# 📝 Edit a report

Click the **NOTE** area of an existing entry.

The report editor will open.

```text
┌──────────────────────────────────────────────┐
│ EDIT REPORT                                  │
├──────────────────────────────────────────────┤
│ Player: SomePlayer                           │
│                                              │
│ [ Repeatedly griefed the group...          ] │
│                                              │
│ [ Toxic ▼ ]        Category                  │
│                                              │
│                         [ SAVE ] [ CANCEL ]   │
└──────────────────────────────────────────────┘
```

The editor allows you to change:

* Report text
* Category

Reports are limited to **255 characters**.

Press **Enter** to save or **Escape** to cancel.

Changes are synchronized with other GuildSharedIgnore users in the guild.

---

# ❌ Remove a player

Click the **×** button on the right side of the player's row.

The entry is removed locally and a removal update is sent to other GuildSharedIgnore users.

GuildSharedIgnore keeps deletion information so that an older copy of an entry cannot simply reappear during synchronization.

---

# 🔄 Synchronization

GuildSharedIgnore synchronizes through WoW's guild addon messaging channel.

### Automatic synchronization

The addon automatically performs synchronization:

* Shortly after loading while in a guild
* When entering the world
* Periodically while in a guild

The periodic automatic synchronization interval is **5 minutes**.

### Manual synchronization

Click:

```text
SYNC
```

or use:

```text
/gsi sync
```

The addon determines whether it can perform an incremental synchronization based on its previous synchronization state.

The interface displays synchronization status such as:

```text
SYNC: READY
SYNC: SYNCING • Incremental
SYNC: OK • Incremental • 2 responder(s)
SYNC: FAILED
```

A completed synchronization reports how many entries were:

* Added locally
* Updated
* Deleted

---

# 📡 Communication

GuildSharedIgnore uses WoW's addon messaging system.

### Addon prefix

```text
GSIgnore
```

Messages are sent through:

```text
GUILD
```

The synchronization system supports:

* Player additions
* Player removals
* Report/category updates
* Synchronization requests
* Version information
* Chunked synchronization data
* Deletion data
* Synchronization completion

Large synchronization datasets are split into smaller packets to remain within WoW addon-message size limits.

The synchronization system also uses timestamps and update information to determine which version of an entry is newer.

---

# 🧠 Synchronization & Conflict Handling

GuildSharedIgnore does not simply overwrite local data whenever another guild member sends an update.

Entries contain update information that allows the addon to compare changes.

Updates are evaluated using:

1. Timestamp
2. Updating player name as a deterministic tie-breaker

This helps prevent older information from overwriting newer information.

### Deletions

Removed entries are tracked using **tombstones**.

This prevents a deleted player from being accidentally restored by an older copy of the shared database during synchronization.

---

# 🛡️ Protection

GuildSharedIgnore can use the shared database to warn you about players before or while interacting with them.

## Chat filtering

Messages from players on the GuildSharedIgnore list can be filtered from supported chat channels.

Supported message types include:

* Say
* Yell
* Whispers
* Party
* Party Leader
* Raid
* Raid Leader
* Raid Warning
* Guild
* Officer
* Channel
* Battleground
* Battleground Leader

The addon filters messages based on the sender being present on the shared list.

---

## 👥 Party & raid warnings

When a group is formed or the group roster changes, GuildSharedIgnore checks the members against the shared list.

If an ignored player is detected, the addon displays a warning containing information such as:

```text
[GSI WARNING] SomePlayer is on the GuildSharedIgnore list [Toxic]: Report text
```

Raid groups can also receive a raid-warning notification.

Warnings are tracked so the same player is not repeatedly announced every time the roster is checked.

---

## 🚫 Party invite protection

If an ignored player sends a party invitation, GuildSharedIgnore can automatically decline the invitation.

The addon also hides the relevant party-invite popup when possible.

A message is displayed in chat indicating that the invitation was automatically declined.

---

# 📢 Guild Announcements

Guild announcements are optional.

Enable:

```text
☑ Announce
```

in the main interface.

When enabled, GuildSharedIgnore can announce additions and removals to guild chat.

### Addition

Example:

```text
[GSI] SomePlayer added by Avarishd [Toxic]: Repeated griefing
```

### Removal

Example:

```text
[GSI] SomePlayer removed by Avarishd [Toxic]: Repeated griefing
```

The category is omitted when it is `Other`.

The report is omitted when no report exists.

---

# 💾 Saved Data

GuildSharedIgnore uses the saved variable:

```text
GuildSharedIgnoreDB
```

The main shared player database is stored under:

```lua
GuildSharedIgnoreDB.players
```

Deletion tracking is stored under:

```lua
GuildSharedIgnoreDB.tombstones
```

The addon also stores synchronization state, including its last successful synchronization time.

Data persists between game sessions.

---

# 📥 Blizzard Ignore List Import

GuildSharedIgnore automatically checks Blizzard's normal ignore list.

Players already present in the Blizzard ignore list can be imported into GuildSharedIgnore.

Imported entries use:

```text
Note:     Ignore List
Category: Other
```

The importing character is recorded as the player who added the entry.

---

# 🔢 Addon Version Detection

GuildSharedIgnore tracks the addon versions currently detected among guild members using the addon.

The interface displays the local addon version.

Hovering over the version displays information about detected GuildSharedIgnore users and their versions.

The highest detected version is shown, and the local version is marked as outdated when a newer addon version is detected in the guild.

This makes it easier for guild members to identify outdated installations.

---

# 🖥️ Interface Controls

The main interface provides:

```text
Player...       → Player to add
Category        → Report category
Note...         → Report text
ADD             → Add player
Search          → Search the shared list
SYNC            → Request synchronization
Announce        → Enable/disable guild announcements
```

Additional controls include:

* Click column headers to sort
* Click a report to edit it
* Click × to remove an entry
* Drag the header to move the window
* Drag the bottom-right corner to resize it
* Press Escape to close active editors/popups
* Right-click supported controls to clear input fields

---

# 🔎 Search

The search field can search the shared list.

It matches against:

```text
Player name
Added by
Note
```

For example:

```text
Search: toxic
```

can find entries containing `toxic` in the player name, the person who added the entry, or the report.

Search results update as you type.

---

# ↕️ Sorting

Click a column header to sort the list.

Supported columns:

```text
PLAYER
ADDED BY
CATEGORY
DATE
```

The active sort direction is shown using arrows:

```text
> PLAYER <
```

Ascending.

Click again:

```text
< PLAYER >
```

Descending.

The same behavior is available for the other sortable columns.

---

# 🎨 Class Colors

Player names and guild-member names can be displayed using their WoW class colors.

Guild class information is obtained from the guild roster.

This makes it easier to identify players at a glance without changing the underlying player data.

---

# 📁 Installation

Download or clone the repository and place the addon folder inside:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── GuildSharedIgnore/
```

The addon folder should contain:

```text
GuildSharedIgnore/
├── GuildSharedIgnore.toc
├── GuildSharedIgnore.lua
├── GuildSharedIgnore_GUI.lua
├── LICENSE
└── README.md
```

Restart the game or reload your UI.

Then type:

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

> GuildSharedIgnore is designed for the **Legion 7.3.5 API (`70300`)**.

---

# 🛠️ Project Structure

```text
GuildSharedIgnore/
│
├── 📄 GuildSharedIgnore.toc
│
├── 📜 GuildSharedIgnore.lua
│   ├── Saved database
│   ├── Player normalization
│   ├── Add / remove logic
│   ├── Report / category updates
│   ├── Blizzard ignore import
│   ├── Guild synchronization
│   ├── Incremental synchronization
│   ├── Deletion tracking
│   ├── Version tracking
│   ├── Chat filtering
│   ├── Group detection
│   ├── Party invite protection
│   └── Guild communication
│
├── 📜 GuildSharedIgnore_GUI.lua
│   ├── Main interface
│   ├── Player entry
│   ├── Category selector
│   ├── Report editor
│   ├── Search
│   ├── Sorting
│   ├── Sync controls
│   ├── Version display
│   ├── Guild addon-user information
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
Version: 3.5
WoW: Legion 7.3.5

Error:
GuildSharedIgnore_GUI.lua:123
attempt to index field 'foo' (a nil value)

Steps:
1. Open /gsi
2. Click a NOTE
3. Edit the report
4. Click SAVE
5. Error occurs
```

The more information provided, the easier the issue is to reproduce and fix.

---

# 💡 Feature Requests

Have an idea for GuildSharedIgnore?

Open an issue describing:

1. What you want added
2. How you expect it to work
3. Why it would be useful
4. Any UI or synchronization considerations

Pull requests are welcome.

---

# 🤝 Contributing

Contributions are welcome.

Before submitting a pull request:

* Keep compatibility with the Legion 7.3.5 API in mind
* Avoid relying on modern Retail-only APIs
* Test synchronization between multiple addon users where possible
* Test both additions and removals
* Test report/category updates
* Test group and invite protection
* Include useful information when fixing a bug

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
