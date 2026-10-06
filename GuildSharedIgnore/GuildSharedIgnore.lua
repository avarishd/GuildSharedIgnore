local ADDON_NAME = "GuildSharedIgnore"
local PREFIX = "GSIgnore"
local VERSION = GetAddOnMetadata(ADDON_NAME, "Version")
local MAX_SYNC_CHUNK = 220
local AUTO_SYNC_INTERVAL = 300
local SYNC_TIMEOUT = 5
GSI = GSI or {}
local syncInProgress = false
local syncBuffer = {}
local syncDeleteBuffer = {}
local syncResponders = {}
local syncRequestID = nil
local syncCounter = 0
local syncStartedAt = 0
local syncSince = 0
local syncWasIncremental = false
local syncImported = 0
local syncUpdated = 0
local syncDeleted = 0
local syncStatus = "Idle"
local syncStatusDetail = ""
local syncLastComplete = 0
local syncNextAuto = 0
local autoSyncTickerStarted = false
local guildClassCache = {}
local addonUsers = {}
local groupWarnedPlayers = {}
local groupWasActive = false
local chatFilterEvents = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_BATTLEGROUND",
    "CHAT_MSG_BATTLEGROUND_LEADER"
}
local CATEGORIES = {
    "Toxic",
    "Bad",
    "Leaver",
    "Scammer",
    "AFK",
    "Bad Attitude",
    "Other"
}
local CATEGORY_LOOKUP = {}
for _, category in ipairs(CATEGORIES) do
    CATEGORY_LOOKUP[string.lower(category)] = category
end
local function InitializeDB()
    GuildSharedIgnoreDB = GuildSharedIgnoreDB or {}
    GuildSharedIgnoreDB.players = GuildSharedIgnoreDB.players or {}
    GuildSharedIgnoreDB.tombstones = GuildSharedIgnoreDB.tombstones or {}
    if GuildSharedIgnoreDB.announceGuild == nil then
        GuildSharedIgnoreDB.announceGuild = false
    end
    if GuildSharedIgnoreDB.lastSyncTime == nil then
        GuildSharedIgnoreDB.lastSyncTime = 0
    end
    for key, entry in pairs(GuildSharedIgnoreDB.players) do
        if entry then
            entry.name = entry.name or key
            entry.addedBy = entry.addedBy or ""
            entry.time = tonumber(entry.time) or 0
            entry.note = entry.note or ""
            entry.category = entry.category or "Other"
            entry.updatedBy = entry.updatedBy or entry.addedBy or ""
        end
    end
end
local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66ccffGuildSharedIgnore|r: " ..
        tostring(message)
    )
end
local function Normalize(name)
    if not name then
        return nil
    end
    name = tostring(name)
    local dash = string.find(name, "-", 1, true)
    if dash then
        name = string.sub(name, 1, dash - 1)
    end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end
local function Key(name)
    name = Normalize(name)
    if not name then
        return nil
    end
    return string.lower(name)
end
local function SanitizeText(text)
    text = text or ""
    text = string.gsub(text, "|", "")
    text = string.gsub(text, ",", "")
    text = string.gsub(text, ";", "")
    text = string.gsub(text, "\r", " ")
    text = string.gsub(text, "\n", " ")
    return text
end
local function SanitizeNote(note)
    return SanitizeText(note)
end
local function SanitizeCategory(category)
    category = SanitizeText(category or "Other")
    local normalized = CATEGORY_LOOKUP[string.lower(category)]
    if normalized then
        return normalized
    end
    return "Other"
end
function GSI.GetCategories()
    local result = {}
    for i, category in ipairs(CATEGORIES) do
        result[i] = category
    end
    return result
end
function GSI.Normalize(name)
    return Normalize(name)
end
function GSI.Key(name)
    return Key(name)
end
local function GetEntry(name)
    local key = Key(name)
    if not key then
        return nil
    end
    return GuildSharedIgnoreDB.players[key]
end
local function IsIgnored(name)
    return GetEntry(name) ~= nil
end
local function GetPlayerName(name)
    local entry = GetEntry(name)
    if entry and entry.name then
        return entry.name
    end
    if name then
        return Normalize(name)
    end
    return Normalize(UnitName("player"))
end
local function FormatDate(timestamp)
    if not timestamp then
        return ""
    end
    return date("%Y-%m-%d %H:%M", timestamp)
end
local function RefreshGuildClassCache()
    guildClassCache = {}
    if not IsInGuild() then
        return
    end
    local totalMembers = GetNumGuildMembers() or 0
    if totalMembers <= 0 then
        return
    end
    for i = 1, totalMembers do
        local guildName,
              rankName,
              rankIndex,
              level,
              classDisplayName,
              zone,
              publicNote,
              officerNote,
              online,
              status,
              classFileName =
            GetGuildRosterInfo(i)
        if guildName and classFileName then
            local key = Key(guildName)
            if key then
                guildClassCache[key] = classFileName
            end
        end
    end
end
local function GetClassColor(name)
    if not name then
        return 1, 1, 1
    end
    local wanted = Key(name)
    if not wanted then
        return 1, 1, 1
    end
    if Key(UnitName("player")) == wanted then
        local _, classFileName = UnitClass("player")
        if classFileName and
           RAID_CLASS_COLORS and
           RAID_CLASS_COLORS[classFileName] then
            local color = RAID_CLASS_COLORS[classFileName]
            return color.r, color.g, color.b
        end
    end
    local classFileName = guildClassCache[wanted]
    if classFileName and
       RAID_CLASS_COLORS and
       RAID_CLASS_COLORS[classFileName] then
        local color = RAID_CLASS_COLORS[classFileName]
        return color.r, color.g, color.b
    end
    if IsInGuild() then
        local totalMembers = GetNumGuildMembers() or 0
        if totalMembers > 0 then
            for i = 1, totalMembers do
                local guildName,
                      rankName,
                      rankIndex,
                      level,
                      classDisplayName,
                      zone,
                      publicNote,
                      officerNote,
                      online,
                      status,
                      classFileName =
                    GetGuildRosterInfo(i)
                if guildName and Key(guildName) == wanted then
                    if classFileName and
                       RAID_CLASS_COLORS and
                       RAID_CLASS_COLORS[classFileName] then
                        guildClassCache[wanted] = classFileName
                        local color = RAID_CLASS_COLORS[classFileName]
                        return color.r, color.g, color.b
                    end
                end
            end
        end
    end
    return 1, 1, 1
end
GSI.GetClassColor = GetClassColor
local function ParseVersion(version)
    version = tostring(version or "0")
    local major,
          minor,
          patch =
        string.match(
            version,
            "^(%d+)%.(%d+)%.?(%d*)"
        )
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    patch = tonumber(patch) or 0
    return major, minor, patch
end
local function CompareVersions(a, b)
    local aMajor,
          aMinor,
          aPatch =
        ParseVersion(a)
    local bMajor,
          bMinor,
          bPatch =
        ParseVersion(b)
    if aMajor ~= bMajor then
        if aMajor > bMajor then
            return 1
        end
        return -1
    end
    if aMinor ~= bMinor then
        if aMinor > bMinor then
            return 1
        end
        return -1
    end
    if aPatch ~= bPatch then
        if aPatch > bPatch then
            return 1
        end
        return -1
    end
    return 0
end
local function RegisterAddonUser(name, version)
    name = Normalize(name)
    version = tostring(version or "")
    if not name or
       name == "" or
       version == "" then
        return
    end
    local key = Key(name)
    if not key then
        return
    end
    addonUsers[key] = {
        name = name,
        version = version,
        lastSeen = time()
    }
end
local function RegisterLocalAddonUser()
    local name =
        Normalize(UnitName("player"))
    if name then
        RegisterAddonUser(name, VERSION)
    end
end
local function GetHighestAddonVersion()
    local highestVersion = VERSION
    for _, user in pairs(addonUsers) do
        if user and user.version and user.version ~= "" then
            if CompareVersions(
                user.version,
                highestVersion
            ) > 0 then
                highestVersion = user.version
            end
        end
    end
    return highestVersion
end
local function IsCurrentVersionHighest()
    local highestVersion =
        GetHighestAddonVersion()
    return CompareVersions(
        VERSION,
        highestVersion
    ) >= 0
end
local function IsCurrentVersionOutdated()
    local highestVersion =
        GetHighestAddonVersion()
    return CompareVersions(
        VERSION,
        highestVersion
    ) < 0
end
local function GetAddonUsers()
    local users = {}
    for _, user in pairs(addonUsers) do
        if user and user.name and user.version then
            table.insert(
                users,
                {
                    name = user.name,
                    version = user.version,
                    lastSeen = user.lastSeen
                }
            )
        end
    end
    table.sort(
        users,
        function(a, b)
            local versionResult =
                CompareVersions(
                    a.version,
                    b.version
                )
            if versionResult ~= 0 then
                return versionResult > 0
            end
            return string.lower(a.name) <
                   string.lower(b.name)
        end
    )
    return users
end
GSI.GetVersion = function()
    return VERSION
end
GSI.GetHighestAddonVersion = function()
    return GetHighestAddonVersion()
end
GSI.IsCurrentVersionHighest = function()
    return IsCurrentVersionHighest()
end
GSI.GetAddonUsers = function()
    return GetAddonUsers()
end
GSI.CompareVersions = function(a, b)
    return CompareVersions(a, b)
end
GSI.RegisterAddonUser = function(name, version)
    RegisterAddonUser(name, version)
end
local function UpdateSyncStatus(status, detail)
    syncStatus = status or "Idle"
    syncStatusDetail = detail or ""
    if GSI.RefreshSyncStatus then
        GSI.RefreshSyncStatus()
    end
end
function GSI.GetSyncStatus()
    return syncStatus,
           syncStatusDetail,
           syncInProgress,
           syncLastComplete,
           syncNextAuto,
           syncWasIncremental,
           syncImported,
           syncUpdated,
           syncDeleted
end
local function RegisterPrefix()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
        return true
    end
    if C_ChatInfo and
       C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        return true
    end
    return false
end
local function SendAddon(message)
    if not message then
        return false
    end
    if string.len(message) > 255 then
        Print("|cffff4444Sync packet too large.|r")
        return false
    end
    if SendAddonMessage then
        SendAddonMessage(
            PREFIX,
            message,
            "GUILD"
        )
        return true
    end
    if C_ChatInfo and
       C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(
            PREFIX,
            message,
            "GUILD"
        )
        return true
    end
    return false
end
GSI.SendAddon = SendAddon
local function GenerateSyncID()
    syncCounter = syncCounter + 1
    return tostring(time()) ..
           "_" ..
           tostring(syncCounter)
end
local function IsIncomingNewer(
    incomingTime,
    incomingBy,
    existingTime,
    existingBy
)
    incomingTime = tonumber(incomingTime) or 0
    existingTime = tonumber(existingTime) or 0
    if incomingTime > existingTime then
        return true
    end
    if incomingTime < existingTime then
        return false
    end
    incomingBy =
        string.lower(
            Normalize(incomingBy or "") or ""
        )
    existingBy =
        string.lower(
            Normalize(existingBy or "") or ""
        )
    return incomingBy > existingBy
end
local function BuildSyncEntries(since)
    local entries = {}
    since = tonumber(since) or 0
    for key, entry in pairs(
        GuildSharedIgnoreDB.players
    ) do
        if entry and entry.name then
            local timestamp =
                tonumber(entry.time) or 0
            if since <= 0 or timestamp >= since then
                local name =
                    SanitizeText(
                        Normalize(entry.name)
                    )
                local addedBy =
                    SanitizeText(
                        Normalize(entry.addedBy or "")
                    )
                local note =
                    SanitizeNote(
                        entry.note or ""
                    )
                local category =
                    SanitizeCategory(
                        entry.category or "Other"
                    )
                local updatedBy =
                    SanitizeText(
                        Normalize(
                            entry.updatedBy or
                            entry.addedBy or
                            ""
                        )
                    )
                local encoded =
                    name ..
                    ";" ..
                    addedBy ..
                    ";" ..
                    tostring(timestamp) ..
                    ";" ..
                    note ..
                    ";" ..
                    category ..
                    ";" ..
                    updatedBy
                table.insert(
                    entries,
                    encoded
                )
            end
        end
    end
    table.sort(
        entries,
        function(a, b)
            return a < b
        end
    )
    return entries
end
local function BuildSyncDeletes(since)
    local deletes = {}
    since = tonumber(since) or 0
    for key, tombstone in pairs(
        GuildSharedIgnoreDB.tombstones
    ) do
        if tombstone and tombstone.name then
            local timestamp =
                tonumber(tombstone.time) or 0
            if since <= 0 or timestamp >= since then
                local name =
                    SanitizeText(
                        Normalize(tombstone.name)
                    )
                local updatedBy =
                    SanitizeText(
                        Normalize(
                            tombstone.updatedBy or ""
                        )
                    )
                table.insert(
                    deletes,
                    name ..
                    ";" ..
                    tostring(timestamp) ..
                    ";" ..
                    updatedBy
                )
            end
        end
    end
    table.sort(
        deletes,
        function(a, b)
            return a < b
        end
    )
    return deletes
end
local function SendChunkedList(
    requestID,
    entries
)
    local chunk = ""
    for i = 1, table.getn(entries) do
        local item = entries[i]
        local separator = ""
        if chunk ~= "" then
            separator = ","
        end
        if string.len(chunk) +
           string.len(separator) +
           string.len(item) >
           MAX_SYNC_CHUNK then
            SendAddon(
                "S|" ..
                requestID ..
                "|" ..
                chunk
            )
            chunk = item
        else
            chunk =
                chunk ..
                separator ..
                item
        end
    end
    if chunk ~= "" then
        SendAddon(
            "S|" ..
            requestID ..
            "|" ..
            chunk
        )
    end
end
local function SendDeleteChunks(
    requestID,
    deletes
)
    local chunk = ""
    for i = 1, table.getn(deletes) do
        local item = deletes[i]
        local separator = ""
        if chunk ~= "" then
            separator = ","
        end
        if string.len(chunk) +
           string.len(separator) +
           string.len(item) >
           MAX_SYNC_CHUNK then
            SendAddon(
                "T|" ..
                requestID ..
                "|" ..
                chunk
            )
            chunk = item
        else
            chunk =
                chunk ..
                separator ..
                item
        end
    end
    if chunk ~= "" then
        SendAddon(
            "T|" ..
            requestID ..
            "|" ..
            chunk
        )
    end
end
local function SendFullList(
    requestID,
    since
)
    local localPlayer =
        Normalize(UnitName("player"))
    SendAddon(
        "V|" ..
        requestID ..
        "|" ..
        localPlayer ..
        "|" ..
        VERSION
    )
    local entries =
        BuildSyncEntries(since)
    local deletes =
        BuildSyncDeletes(since)
    SendChunkedList(
        requestID,
        entries
    )
    SendDeleteChunks(
        requestID,
        deletes
    )
    SendAddon(
        "E|" ..
        requestID
    )
end
local function ProcessSyncBuffer()
    local imported = 0
    local updated = 0
    local deleted = 0
    local bufferCount =
        table.getn(syncBuffer)
    for i = 1, bufferCount do
        local data = syncBuffer[i]
        local name,
              addedBy,
              timestamp,
              note,
              category,
              updatedBy =
            string.match(
                data,
                "^([^;]+);([^;]*);([^;]*);([^;]*);([^;]*);(.*)$"
            )
        if name then
            name = Normalize(name)
            local key = Key(name)
            timestamp =
                tonumber(timestamp) or time()
            addedBy =
                Normalize(addedBy or "")
            note =
                SanitizeNote(note or "")
            category =
                SanitizeCategory(category or "Other")
            updatedBy =
                Normalize(
                    updatedBy or
                    addedBy or
                    ""
                )
            if key then
                local existing =
                    GuildSharedIgnoreDB.players[key]
                local tombstone =
                    GuildSharedIgnoreDB.tombstones[key]
                local tombstoneTime =
                    tombstone and
                    tonumber(tombstone.time) or
                    0
                local tombstoneBy =
                    tombstone and
                    tombstone.updatedBy or
                    ""
                if IsIncomingNewer(
                    timestamp,
                    updatedBy,
                    tombstoneTime,
                    tombstoneBy
                ) then
                    if not existing then
                        GuildSharedIgnoreDB.players[key] = {
                            name = name,
                            addedBy = addedBy,
                            time = timestamp,
                            note = note,
                            category = category,
                            updatedBy = updatedBy
                        }
                        imported = imported + 1
                    elseif IsIncomingNewer(
                        timestamp,
                        updatedBy,
                        tonumber(existing.time) or 0,
                        existing.updatedBy or existing.addedBy or ""
                    ) then
                        existing.name = name
                        existing.addedBy = addedBy
                        existing.time = timestamp
                        existing.note = note
                        existing.category = category
                        existing.updatedBy = updatedBy
                        updated = updated + 1
                    end
                end
            end
        end
    end
    local deleteCount =
        table.getn(syncDeleteBuffer)
    for i = 1, deleteCount do
        local data =
            syncDeleteBuffer[i]
        local name,
              timestamp,
              updatedBy =
            string.match(
                data,
                "^([^;]+);([^;]*);(.*)$"
            )
        if name then
            name = Normalize(name)
            local key = Key(name)
            timestamp =
                tonumber(timestamp) or time()
            updatedBy =
                Normalize(updatedBy or "")
            if key then
                local existing =
                    GuildSharedIgnoreDB.players[key]
                local tombstone =
                    GuildSharedIgnoreDB.tombstones[key]
                local existingTime =
                    existing and
                    tonumber(existing.time) or
                    0
                local existingBy =
                    existing and
                    (
                        existing.updatedBy or
                        existing.addedBy or
                        ""
                    ) or
                    ""
                local tombstoneTime =
                    tombstone and
                    tonumber(tombstone.time) or
                    0
                local tombstoneBy =
                    tombstone and
                    tombstone.updatedBy or
                    ""
                if IsIncomingNewer(
                    timestamp,
                    updatedBy,
                    existingTime,
                    existingBy
                ) and
                   IsIncomingNewer(
                       timestamp,
                       updatedBy,
                       tombstoneTime,
                       tombstoneBy
                   ) then
                    GuildSharedIgnoreDB.players[key] = nil
                    GuildSharedIgnoreDB.tombstones[key] = {
                        name = name,
                        time = timestamp,
                        updatedBy = updatedBy
                    }
                    deleted = deleted + 1
                elseif not existing and
                       IsIncomingNewer(
                           timestamp,
                           updatedBy,
                           tombstoneTime,
                           tombstoneBy
                       ) then
                    GuildSharedIgnoreDB.tombstones[key] = {
                        name = name,
                        time = timestamp,
                        updatedBy = updatedBy
                    }
                end
            end
        end
    end
    syncBuffer = {}
    syncDeleteBuffer = {}
    if GSI.RefreshList then
        GSI.RefreshList()
    end
    return imported, updated, deleted
end
local function RequestSync()
    if not IsInGuild() then
        UpdateSyncStatus(
            "Failed",
            "Not in a guild"
        )
        Print(
            "|cffff4444Sync failed: not in a guild.|r"
        )
        return
    end
    if syncInProgress then
        UpdateSyncStatus(
            "Syncing",
            "Already in progress"
        )
        return
    end
    RegisterPrefix()
    RegisterLocalAddonUser()
    syncRequestID =
        GenerateSyncID()
    syncBuffer = {}
    syncDeleteBuffer = {}
    syncResponders = {}
    syncImported = 0
    syncUpdated = 0
    syncDeleted = 0
    syncInProgress = true
    syncStartedAt = time()
    syncSince =
        tonumber(
            GuildSharedIgnoreDB.lastSyncTime
        ) or 0
    syncWasIncremental =
        syncSince > 0
    if syncWasIncremental then
        UpdateSyncStatus(
            "Syncing",
            "Incremental"
        )
    else
        UpdateSyncStatus(
            "Syncing",
            "Full"
        )
    end
    local playerName =
        Normalize(UnitName("player"))
    local message =
        "Q|" ..
        syncRequestID ..
        "|" ..
        playerName ..
        "|" ..
        tostring(syncSince)
    if not SendAddon(message) then
        syncInProgress = false
        UpdateSyncStatus(
            "Failed",
            "Addon messaging unavailable"
        )
        Print(
            "|cffff4444Sync failed: addon messaging unavailable.|r"
        )
        return
    end
    Print(
        "Sync requested" ..
        (
            syncWasIncremental
            and " (incremental)..."
            or " (full)..."
        )
    )
    if C_Timer and C_Timer.After then
        C_Timer.After(
            SYNC_TIMEOUT,
            function()
                if not syncInProgress then
                    return
                end
                syncInProgress = false
                local imported,
                      updated,
                      deleted =
                    ProcessSyncBuffer()
                syncImported = imported
                syncUpdated = updated
                syncDeleted = deleted
                local responders = 0
                for sender in pairs(syncResponders) do
                    responders = responders + 1
                end
                if responders > 0 then
                    GuildSharedIgnoreDB.lastSyncTime =
                        time()
                    syncLastComplete =
                        time()
                end
                local statusText =
                    (
                        syncWasIncremental
                        and "Incremental"
                        or "Full"
                    ) ..
                    " • " ..
                    tostring(responders) ..
                    " responder(s)"
                UpdateSyncStatus(
                    responders > 0
                    and "Complete"
                    or "Failed",
                    statusText
                )
                if GSI.RefreshVersionDisplay then
                    GSI.RefreshVersionDisplay()
                end
                Print(
                    "Sync complete. " ..
                    tostring(responders) ..
                    " responder(s), " ..
                    tostring(imported) ..
                    " new, " ..
                    tostring(updated) ..
                    " updated, " ..
                    tostring(deleted) ..
                    " deleted."
                )
                syncNextAuto =
                    time() +
                    AUTO_SYNC_INTERVAL
                if GSI.RefreshSyncStatus then
                    GSI.RefreshSyncStatus()
                end
            end
        )
    end
end
GSI.RequestSync = RequestSync
local function HandleMessage(
    prefix,
    message,
    distribution,
    sender
)
    if prefix ~= PREFIX then
        return
    end
    if not message then
        return
    end
    sender =
        Normalize(sender or "")
    if string.sub(message, 1, 2) == "A|" then
        local name,
              addedBy,
              timestamp,
              note,
              category =
            string.match(
                message,
                "^A|([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)"
            )
        if name then
            local key = Key(name)
            if key then
                name = Normalize(name)
                addedBy = Normalize(addedBy or "")
                timestamp = tonumber(timestamp) or time()
                note = SanitizeNote(note or "")
                category = SanitizeCategory(category or "Other")
                local existing =
                    GuildSharedIgnoreDB.players[key]
                local updatedBy =
                    addedBy
                if not existing or
                   IsIncomingNewer(
                       timestamp,
                       updatedBy,
                       tonumber(existing.time) or 0,
                       existing.updatedBy or existing.addedBy or ""
                   ) then
                    GuildSharedIgnoreDB.players[key] = {
                        name = name,
                        addedBy = addedBy,
                        time = timestamp,
                        note = note,
                        category = category,
                        updatedBy = updatedBy
                    }
                    GuildSharedIgnoreDB.tombstones[key] = nil
                    if GSI.RefreshList then
                        GSI.RefreshList()
                    end
                end
            end
        end
        return
    end
    if string.sub(message, 1, 2) == "R|" then
        local name,
              removedBy,
              timestamp =
            string.match(
                message,
                "^R|([^|]+)|([^|]*)|([^|]*)"
            )
        if name then
            local key = Key(name)
            if key then
                name = Normalize(name)
                removedBy = Normalize(removedBy or "")
                timestamp = tonumber(timestamp) or time()
                local existing =
                    GuildSharedIgnoreDB.players[key]
                local tombstone =
                    GuildSharedIgnoreDB.tombstones[key]
                local existingTime =
                    existing and
                    tonumber(existing.time) or
                    0
                local existingBy =
                    existing and
                    (
                        existing.updatedBy or
                        existing.addedBy or
                        ""
                    ) or
                    ""
                local tombstoneTime =
                    tombstone and
                    tonumber(tombstone.time) or
                    0
                local tombstoneBy =
                    tombstone and
                    tombstone.updatedBy or
                    ""
                if IsIncomingNewer(
                    timestamp,
                    removedBy,
                    existingTime,
                    existingBy
                ) and
                   IsIncomingNewer(
                       timestamp,
                       removedBy,
                       tombstoneTime,
                       tombstoneBy
                   ) then
                    GuildSharedIgnoreDB.players[key] = nil
                    GuildSharedIgnoreDB.tombstones[key] = {
                        name = name,
                        time = timestamp,
                        updatedBy = removedBy
                    }
                    if GSI.RefreshList then
                        GSI.RefreshList()
                    end
                end
            end
        end
        return
    end
    if string.sub(message, 1, 2) == "N|" then
        local name,
              note,
              timestamp,
              category,
              updatedBy =
            string.match(
                message,
                "^N|([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)"
            )
        if name then
            local key = Key(name)
            local entry =
                GuildSharedIgnoreDB.players[key]
            if entry then
                timestamp =
                    tonumber(timestamp) or time()
                updatedBy =
                    Normalize(
                        updatedBy or sender or ""
                    )
                if IsIncomingNewer(
                    timestamp,
                    updatedBy,
                    tonumber(entry.time) or 0,
                    entry.updatedBy or entry.addedBy or ""
                ) then
                    entry.note =
                        SanitizeNote(note or "")
                    entry.time =
                        timestamp
                    entry.category =
                        SanitizeCategory(
                            category or
                            entry.category or
                            "Other"
                        )
                    entry.updatedBy =
                        updatedBy
                    if GSI.RefreshList then
                        GSI.RefreshList()
                    end
                end
            end
        end
        return
    end
    if string.sub(message, 1, 2) == "Q|" then
        local requestID,
              requester,
              since =
            string.match(
                message,
                "^Q|([^|]+)|([^|]+)|([^|]*)$"
            )
        if not requestID or
           not requester then
            return
        end
        requester =
            Normalize(requester)
        since =
            tonumber(since) or 0
        local localPlayer =
            Normalize(UnitName("player"))
        if Key(requester) ==
           Key(localPlayer) then
            return
        end
        RegisterAddonUser(
            requester,
            "0.0.0"
        )
        SendFullList(
            requestID,
            since
        )
        return
    end
    if string.sub(message, 1, 2) == "V|" then
        local requestID,
              playerName,
              version =
            string.match(
                message,
                "^V|([^|]+)|([^|]+)|([^|]+)$"
            )
        if not requestID or
           not playerName or
           not version then
            return
        end
        if not syncInProgress then
            return
        end
        if requestID ~= syncRequestID then
            return
        end
        if Key(playerName) ==
           Key(UnitName("player")) then
            return
        end
        RegisterAddonUser(
            playerName,
            version
        )
        syncResponders[playerName] = true
        if GSI.RefreshVersionDisplay then
            GSI.RefreshVersionDisplay()
        end
        if GSI.RefreshSyncStatus then
            GSI.RefreshSyncStatus()
        end
        return
    end
    if string.sub(message, 1, 2) == "S|" then
        local requestID,
              chunk =
            string.match(
                message,
                "^S|([^|]+)|(.+)$"
            )
        if not requestID or
           not chunk then
            return
        end
        if not syncInProgress then
            return
        end
        if requestID ~= syncRequestID then
            return
        end
        if Key(sender) ==
           Key(UnitName("player")) then
            return
        end
        syncResponders[sender] = true
        for item in string.gmatch(
            chunk,
            "([^,]+)"
        ) do
            table.insert(
                syncBuffer,
                item
            )
        end
        return
    end
    if string.sub(message, 1, 2) == "T|" then
        local requestID,
              chunk =
            string.match(
                message,
                "^T|([^|]+)|(.+)$"
            )
        if not requestID or
           not chunk then
            return
        end
        if not syncInProgress then
            return
        end
        if requestID ~= syncRequestID then
            return
        end
        if Key(sender) ==
           Key(UnitName("player")) then
            return
        end
        syncResponders[sender] = true
        for item in string.gmatch(
            chunk,
            "([^,]+)"
        ) do
            table.insert(
                syncDeleteBuffer,
                item
            )
        end
        return
    end
    if string.sub(message, 1, 2) == "E|" then
        local requestID =
            string.match(
                message,
                "^E|([^|]+)"
            )
        if not requestID then
            return
        end
        if not syncInProgress then
            return
        end
        if requestID ~= syncRequestID then
            return
        end
        if Key(sender) ==
           Key(UnitName("player")) then
            return
        end
        syncResponders[sender] = true
        return
    end
end
function GSI.AddPlayer(
    name,
    note,
    addedBy,
    category
)
    name = Normalize(name)
    if not name or name == "" then
        return false
    end
    local key = Key(name)
    if not key then
        return false
    end
    addedBy =
        Normalize(
            addedBy or
            UnitName("player")
        )
    category =
        SanitizeCategory(
            category or "Other"
        )
    local timestamp = time()
    GuildSharedIgnoreDB.players[key] = {
        name = name,
        addedBy = addedBy,
        time = timestamp,
        note = SanitizeNote(note or ""),
        category = category,
        updatedBy = addedBy
    }
    GuildSharedIgnoreDB.tombstones[key] = nil
    SendAddon(
        "A|" ..
        name ..
        "|" ..
        addedBy ..
        "|" ..
        tostring(timestamp) ..
        "|" ..
        SanitizeNote(note or "") ..
        "|" ..
        category
    )
    if GSI.RefreshList then
        GSI.RefreshList()
    end
    return true
end
function GSI.RemovePlayer(name)
    name = Normalize(name)
    if not name then
        return false
    end
    local key = Key(name)
    if not key then
        return false
    end
    if not GuildSharedIgnoreDB.players[key] then
        return false
    end
    local timestamp = time()
    local removedBy =
        Normalize(UnitName("player"))
    GuildSharedIgnoreDB.players[key] = nil
    GuildSharedIgnoreDB.tombstones[key] = {
        name = name,
        time = timestamp,
        updatedBy = removedBy
    }
    SendAddon(
        "R|" ..
        name ..
        "|" ..
        removedBy ..
        "|" ..
        tostring(timestamp)
    )
    if GSI.RefreshList then
        GSI.RefreshList()
    end
    return true
end
function GSI.UpdateNote(
    name,
    note,
    category
)
    name = Normalize(name)
    if not name then
        return false
    end
    local key = Key(name)
    if not key then
        return false
    end
    local entry =
        GuildSharedIgnoreDB.players[key]
    if not entry then
        return false
    end
    note =
        SanitizeNote(note or "")
    category =
        SanitizeCategory(
            category or
            entry.category or
            "Other"
        )
    local timestamp = time()
    local updatedBy =
        Normalize(UnitName("player"))
    entry.note = note
    entry.category = category
    entry.time = timestamp
    entry.updatedBy = updatedBy
    SendAddon(
        "N|" ..
        name ..
        "|" ..
        note ..
        "|" ..
        tostring(timestamp) ..
        "|" ..
        category ..
        "|" ..
        updatedBy
    )
    if GSI.RefreshList then
        GSI.RefreshList()
    end
    return true
end
local function ImportBlizzardIgnoreList()
    if GetNumIgnores and
       GetIgnoreName then
        local total =
            tonumber(GetNumIgnores()) or 0
        if total <= 0 then
            return
        end
        for i = 1, total do
            local name =
                GetIgnoreName(i)
            if name then
                local key = Key(name)
                if key and
                   not GuildSharedIgnoreDB.players[key] then
                    local addedBy =
                        Normalize(
                            UnitName("player")
                        )
                    GuildSharedIgnoreDB.players[key] = {
                        name = Normalize(name),
                        addedBy = addedBy,
                        time = time(),
                        note = "Ignore List",
                        category = "Other",
                        updatedBy = addedBy
                    }
                end
            end
        end
    end
end
local function WarnAboutGroupMember(name)
    local key = Key(name)
    if not key then
        return
    end
    if groupWarnedPlayers[key] then
        return
    end
    local entry = GuildSharedIgnoreDB.players[key]
    if not entry then
        return
    end
    groupWarnedPlayers[key] = true
    local displayName =
        entry.name or Normalize(name)
    local category =
        entry.category or "Other"
    local note =
        entry.note or ""
    local message =
        "|cffff4444[GSI WARNING]|r " ..
        tostring(displayName) ..
        " is on the GuildSharedIgnore list"
    if category ~= "" and
       category ~= "Other" then
        message =
            message ..
            " [" ..
            tostring(category) ..
            "]"
    end
    if note ~= "" then
        message =
            message ..
            ": " ..
            tostring(note)
    end
    Print(message)
    if RaidNotice_AddMessage and
       RaidWarningFrame and
       ChatTypeInfo and
       ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(
            RaidWarningFrame,
            "|cffff3333[GSI] " ..
            tostring(displayName) ..
            " is on the ignore list!|r",
            ChatTypeInfo["RAID_WARNING"]
        )
    end
end
local function CheckGroupMembers()
    if not GuildSharedIgnoreDB or
       not GuildSharedIgnoreDB.players then
        return
    end
    local inParty =
        IsInGroup and
        IsInGroup()
    local inRaid =
        IsInRaid and
        IsInRaid()
    if not inParty and
       not inRaid then
        if groupWasActive then
            groupWarnedPlayers = {}
            groupWasActive = false
        end
        return
    end
    groupWasActive = true
    if inRaid then
        local total =
            GetNumGroupMembers() or 0
        for i = 1, total do
            local unit = "raid" .. tostring(i)
            if UnitExists(unit) then
                local name =
                    UnitName(unit)
                if name then
                    WarnAboutGroupMember(name)
                end
            end
        end
    else
        local total =
            GetNumGroupMembers() or 0
        for i = 1, total do
            local unit = "party" .. tostring(i)
            if UnitExists(unit) then
                local name =
                    UnitName(unit)
                if name then
                    WarnAboutGroupMember(name)
                end
            end
        end
    end
end
local function GSIChatFilter(self,event,message,author,...)
    if not author or author == "" then
        return false
    end
    local playerName =
        Normalize(UnitName("player"))
    local senderName =
        Normalize(author)
    if not senderName or
       not playerName then
        return false
    end
    if Key(senderName) ==
       Key(playerName) then
        return false
    end
    if IsIgnored(senderName) then
        return true
    end
    return false
end
local function RegisterChatFilters()
    if not ChatFrame_AddMessageEventFilter then
        return
    end
    for i = 1, table.getn(chatFilterEvents) do
        ChatFrame_AddMessageEventFilter(
            chatFilterEvents[i],
            GSIChatFilter
        )
    end
end
local function HandlePartyInvite(inviter)
    if not inviter or inviter == "" then
        return
    end
    local name =
        Normalize(inviter)
    if not name then
        return
    end
    if not IsIgnored(name) then
        return
    end
    local entry =
        GetEntry(name)
    local displayName =
        entry and entry.name or name
    Print(
        "|cffff4444[GSI]|r Automatically declined party invite from " ..
        tostring(displayName) ..
        "."
    )
    if DeclineGroupInvite then
        pcall(
            DeclineGroupInvite
        )
    elseif C_PartyInfo and
           C_PartyInfo.DeclineInvite then
        pcall(
            C_PartyInfo.DeclineInvite
        )
    end
    if StaticPopup_Hide then
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
    end
end
local eventFrame =
    CreateFrame(
        "Frame",
        "GuildSharedIgnoreEventFrame"
    )
eventFrame:RegisterEvent(
    "ADDON_LOADED"
)
eventFrame:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)
eventFrame:RegisterEvent(
    "CHAT_MSG_ADDON"
)
eventFrame:RegisterEvent(
    "GUILD_ROSTER_UPDATE"
)
eventFrame:RegisterEvent(
    "GROUP_ROSTER_UPDATE"
)
eventFrame:RegisterEvent(
    "PARTY_INVITE_REQUEST"
)
eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName ~= ADDON_NAME then
                return
            end
            InitializeDB()
            RegisterPrefix()
            RegisterLocalAddonUser()
            ImportBlizzardIgnoreList()
            RegisterChatFilters()
            if IsInGuild() then
                if GuildRoster then
                    GuildRoster()
                end
                RefreshGuildClassCache()
            end
            if C_Timer and
               C_Timer.After then
                C_Timer.After(
                    3,
                    function()
                        if IsInGuild() then
                            if GuildRoster then
                                GuildRoster()
                            end
                            RefreshGuildClassCache()
                            RegisterLocalAddonUser()
                            RequestSync()
                        end
                    end
                )
                if C_Timer.NewTicker and
                   not autoSyncTickerStarted then
                    autoSyncTickerStarted = true
                    syncNextAuto =
                        time() +
                        AUTO_SYNC_INTERVAL
                    C_Timer.NewTicker(
                        AUTO_SYNC_INTERVAL,
                        function()
                            if IsInGuild() then
                                syncNextAuto =
                                    time() +
                                    AUTO_SYNC_INTERVAL
                                RequestSync()
                            end
                        end
                    )
                end
            end
            if GSI.RefreshList then
                GSI.RefreshList()
            end
            if GSI.RefreshVersionDisplay then
                GSI.RefreshVersionDisplay()
            end
            if GSI.RefreshSyncStatus then
                GSI.RefreshSyncStatus()
            end
            Print(
                "Loaded v" ..
                VERSION
            )
            return
        end
        if event == "PLAYER_ENTERING_WORLD" then
            InitializeDB()
            RegisterPrefix()
            RegisterLocalAddonUser()
            RegisterChatFilters()
            if C_Timer and
               C_Timer.After then
                C_Timer.After(
                    2,
                    function()
                        if IsInGuild() then
                            if GuildRoster then
                                GuildRoster()
                            end
                            RefreshGuildClassCache()
                            ImportBlizzardIgnoreList()
                            RegisterLocalAddonUser()
                            CheckGroupMembers()
                            if GSI.RefreshList then
                                GSI.RefreshList()
                            end
                        end
                    end
                )
                C_Timer.After(
                    5,
                    function()
                        if IsInGuild() then
                            RequestSync()
                        end
                    end
                )
            end
            return
        end
        if event == "GUILD_ROSTER_UPDATE" then
            RefreshGuildClassCache()
            if GSI.RefreshList then
                GSI.RefreshList()
            end
            return
        end
        if event == "GROUP_ROSTER_UPDATE" then
            CheckGroupMembers()
            return
        end
        if event == "PARTY_INVITE_REQUEST" then
            local inviter = ...
            HandlePartyInvite(inviter)
            return
        end
        if event == "CHAT_MSG_ADDON" then
            local prefix,
                  message,
                  distribution,
                  sender =
                ...
            HandleMessage(
                prefix,
                message,
                distribution,
                sender
            )
            return
        end
    end
)
SLASH_GUILDSHAREDIGNORE1 = "/gsi"
SlashCmdList["GUILDSHAREDIGNORE"] =
function(msg)
    msg =
        string.lower(
            string.gsub(
                msg or "",
                "^%s+",
                ""
            )
        )
    if msg == "sync" then
        RequestSync()
        return
    end
    if msg == "debug" then
        Print(
            "Version: " ..
            VERSION
        )
        Print(
            "Prefix: " ..
            PREFIX
        )
        Print(
            "In guild: " ..
            tostring(IsInGuild())
        )
        Print(
            "Sync active: " ..
            tostring(syncInProgress)
        )
        Print(
            "Sync status: " ..
            tostring(syncStatus)
        )
        Print(
            "Sync detail: " ..
            tostring(syncStatusDetail)
        )
        Print(
            "Incremental: " ..
            tostring(syncWasIncremental)
        )
        Print(
            "Last sync: " ..
            tostring(
                GuildSharedIgnoreDB.lastSyncTime
            )
        )
        Print(
            "Next auto sync: " ..
            tostring(syncNextAuto)
        )
        local responderCount = 0
        for sender in pairs(syncResponders) do
            responderCount =
                responderCount + 1
            Print(
                "Responder: " ..
                tostring(sender)
            )
        end
        Print(
            "Responders: " ..
            tostring(responderCount)
        )
        Print("Addon users:")
        local users =
            GetAddonUsers()
        for i, user in ipairs(users) do
            Print(
                "  " ..
                tostring(user.name) ..
                " - v" ..
                tostring(user.version)
            )
        end
        Print(
            "Highest version: v" ..
            tostring(
                GetHighestAddonVersion()
            )
        )
        return
    end
    if msg == "version" then
        Print(
            "GuildSharedIgnore v" ..
            VERSION
        )
        Print(
            "Highest detected version: v" ..
            GetHighestAddonVersion()
        )
        return
    end
    if not GSI.CreateUI then
        Print(
            "|cffff4444GuildSharedIgnore GUI is not loaded.|r"
        )
        return
    end
    GSI.CreateUI()
    if GSI.GetFrame then
        local uiFrame =
            GSI.GetFrame()
        if uiFrame then
            if uiFrame:IsShown() then
                uiFrame:Hide()
            else
                uiFrame:Show()
                uiFrame:Raise()
                uiFrame:EnableKeyboard(true)
                uiFrame:SetPropagateKeyboardInput(true)
                if GSI.RefreshList then
                    GSI.RefreshList()
                end
                if GSI.RefreshVersionDisplay then
                    GSI.RefreshVersionDisplay()
                end
                if GSI.RefreshSyncStatus then
                    GSI.RefreshSyncStatus()
                end
            end
            return
        end
    end
    if GSI.ToggleUI then
        GSI.ToggleUI()
        return
    end
    Print(
        "|cffff4444GuildSharedIgnore GUI loaded but could not be opened.|r"
    )
end
GSI.GetEntry = GetEntry
GSI.IsIgnored = IsIgnored
GSI.GetPlayerName = GetPlayerName
GSI.FormatDate = FormatDate
GSI.Normalize = Normalize
GSI.Key = Key
GSI.SetSortState =
function(column, ascending)
    GSI.sortColumn = column
    GSI.sortAscending = ascending
end
GSI.GetSortState =
function()
    return GSI.sortColumn,
           GSI.sortAscending
end
InitializeDB()
RegisterPrefix()
RegisterLocalAddonUser()
RegisterChatFilters()
