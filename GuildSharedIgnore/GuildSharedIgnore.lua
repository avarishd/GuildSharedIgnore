local ADDON_NAME="GuildSharedIgnore"
local PREFIX="GSIgnore"
local VERSION=GetAddOnMetadata(ADDON_NAME,"Version") or "4.0"
local MAX_PACKET=240
local SYNC_TIMEOUT=10
local AUTO_SYNC_INTERVAL=300
local ADDON_USER_TTL=86400
GSI=GSI or {}
local syncActive=false
local syncID=nil
local syncStartedAt=0
local syncResponders={}
local syncExpected={}
local syncChunks={}
local syncDeleteChunks={}
local syncImported=0
local syncUpdated=0
local syncDeleted=0
local syncStatus="Idle"
local syncStatusDetail=""
local syncLastComplete=0
local syncNextAuto=0
local autoTickerStarted=false
local chatFiltersRegistered=false
local guildClassCache={}
local addonUsers={}
local groupWarnedPlayers={}
local groupMembers={}
local CATEGORIES={"Toxic","Bad","Leaver","Scammer","AFK","Bad Attitude","Other"}
local CATEGORY_LOOKUP={}
for _,v in ipairs(CATEGORIES) do CATEGORY_LOOKUP[string.lower(v)]=v end
local chatFilterEvents={"CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_CHANNEL","CHAT_MSG_BATTLEGROUND","CHAT_MSG_BATTLEGROUND_LEADER"}

local function Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffGuildSharedIgnore|r: "..tostring(msg)) end
end
local function Normalize(name)
    if not name then return nil end
    name=tostring(name):gsub("^%s+",""):gsub("%s+$","")
    local dash=name:find("-",1,true)
    if dash then name=name:sub(1,dash-1) end
    if name=="" then return nil end
    return name
end
local function Key(name)
    name=Normalize(name)
    return name and string.lower(name) or nil
end
local function Encode(s)
    s=tostring(s or "")
    s=s:gsub("%%","%%25"):gsub("|","%%7C"):gsub(";","%%3B"):gsub(",","%%2C"):gsub("\r","%%0D"):gsub("\n","%%0A")
    return s
end
local function Decode(s)
    s=tostring(s or "")
    s=s:gsub("%%0A","\n"):gsub("%%0D","\r"):gsub("%%2C",","):gsub("%%3B",";"):gsub("%%7C","|"):gsub("%%25","%%")
    return s
end
local function SanitizeCategory(category)
    category=tostring(category or "Other")
    return CATEGORY_LOOKUP[string.lower(category)] or "Other"
end
local function SanitizeNote(note)
    note=tostring(note or ""):gsub("\r"," "):gsub("\n"," ")
    if #note>255 then note=note:sub(1,255) end
    return note
end
local function LocalName()
    return Normalize(UnitName("player")) or "Unknown"
end
local function InitializeDB()
    GuildSharedIgnoreDB=GuildSharedIgnoreDB or {}
    GuildSharedIgnoreDB.players=GuildSharedIgnoreDB.players or {}
    GuildSharedIgnoreDB.tombstones=GuildSharedIgnoreDB.tombstones or {}
    GuildSharedIgnoreDB.logicalClock=tonumber(GuildSharedIgnoreDB.logicalClock) or 0
    GuildSharedIgnoreDB.databaseRevision=tonumber(GuildSharedIgnoreDB.databaseRevision) or 0
    if GuildSharedIgnoreDB.announceGuild==nil then GuildSharedIgnoreDB.announceGuild=false end
    GuildSharedIgnoreDB.lastSyncTime=tonumber(GuildSharedIgnoreDB.lastSyncTime) or 0
    local maxRevision=tonumber(GuildSharedIgnoreDB.logicalClock) or 0
    for key,e in pairs(GuildSharedIgnoreDB.players) do
        if e then
            e.name=Normalize(e.name or key) or key
            e.addedBy=Normalize(e.addedBy or "") or ""
            e.note=SanitizeNote(e.note or "")
            e.category=SanitizeCategory(e.category)
            e.updatedBy=Normalize(e.updatedBy or e.addedBy) or ""
            e.time=tonumber(e.time) or 0
            e.rev=tonumber(e.rev) or e.time or 0
            if e.rev>maxRevision then maxRevision=e.rev end
        else GuildSharedIgnoreDB.players[key]=nil end
    end
    for key,t in pairs(GuildSharedIgnoreDB.tombstones) do
        if t then
            t.name=Normalize(t.name or key) or key
            t.updatedBy=Normalize(t.updatedBy or "") or ""
            t.time=tonumber(t.time) or 0
            t.rev=tonumber(t.rev) or t.time or 0
            if t.rev>maxRevision then maxRevision=t.rev end
        else GuildSharedIgnoreDB.tombstones[key]=nil end
    end
    if maxRevision>(GuildSharedIgnoreDB.logicalClock or 0) then GuildSharedIgnoreDB.logicalClock=maxRevision end
end
local function NextRevision()
    InitializeDB()
    local r=tonumber(GuildSharedIgnoreDB.logicalClock) or 0
    r=r+1
    GuildSharedIgnoreDB.logicalClock=r
    GuildSharedIgnoreDB.databaseRevision=(tonumber(GuildSharedIgnoreDB.databaseRevision) or 0)+1
    return r
end
local function AdvanceClock(rev)
    rev=tonumber(rev) or 0
    InitializeDB()
    if rev>(GuildSharedIgnoreDB.logicalClock or 0) then GuildSharedIgnoreDB.logicalClock=rev end
end
local function CompareVersions(a,b)
    local function p(v)
        local a1,a2,a3=tostring(v or "0"):match("^(%d+)%.(%d+)%.?(%d*)")
        return tonumber(a1) or 0,tonumber(a2) or 0,tonumber(a3) or 0
    end
    local a1,a2,a3=p(a); local b1,b2,b3=p(b)
    if a1~=b1 then return a1>b1 and 1 or -1 end
    if a2~=b2 then return a2>b2 and 1 or -1 end
    if a3~=b3 then return a3>b3 and 1 or -1 end
    return 0
end
local function RegisterAddonUser(name,version)
    name=Normalize(name); version=tostring(version or "")
    if not name or version=="" then return end
    addonUsers[Key(name)]={name=name,version=version,lastSeen=time()}
end
local function PruneAddonUsers()
    local now=time()
    for key,u in pairs(addonUsers) do
        if not u or not u.lastSeen or now-u.lastSeen>ADDON_USER_TTL then addonUsers[key]=nil end
    end
end
local function GetAddonUsers()
    PruneAddonUsers()
    local out={}
    for _,u in pairs(addonUsers) do if u then out[#out+1]={name=u.name,version=u.version,lastSeen=u.lastSeen} end end
    table.sort(out,function(a,b)
        local c=CompareVersions(a.version,b.version)
        if c~=0 then return c>0 end
        return string.lower(a.name)<string.lower(b.name)
    end)
    return out
end
local function GetHighestAddonVersion()
    local high=VERSION
    for _,u in ipairs(GetAddonUsers()) do if CompareVersions(u.version,high)>0 then high=u.version end end
    return high
end
local function RefreshStatus()
    if GSI.RefreshSyncStatus then GSI.RefreshSyncStatus() end
end
local function UpdateSyncStatus(status,detail)
    syncStatus=status or "Idle"; syncStatusDetail=detail or ""; RefreshStatus()
end
local function RegisterPrefix()
    if RegisterAddonMessagePrefix then return RegisterAddonMessagePrefix(PREFIX) ~= false end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then return C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) ~= false end
    return false
end
local function SendAddon(msg,target)
    if not msg or #msg>255 then return false end
    if SendAddonMessage then
        SendAddonMessage(PREFIX,msg,target and "WHISPER" or "GUILD",target)
        return true
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX,msg,target and "WHISPER" or "GUILD",target)
        return true
    end
    return false
end
local function GenerateSyncID()
    GSI._syncCounter=(tonumber(GSI._syncCounter) or 0)+1
    return tostring(time()).."_"..tostring(GSI._syncCounter).."_"..tostring(math.random(1000,9999))
end
local function IsNewer(inRev,inBy,oldRev,oldBy)
    inRev=tonumber(inRev) or 0; oldRev=tonumber(oldRev) or 0
    if inRev~=oldRev then return inRev>oldRev end
    inBy=string.lower(Normalize(inBy or "") or ""); oldBy=string.lower(Normalize(oldBy or "") or "")
    return inBy>oldBy
end
local function GetEntry(name)
    local k=Key(name); return k and GuildSharedIgnoreDB.players[k] or nil
end
local function IsIgnored(name) return GetEntry(name)~=nil end
local function FormatDate(ts) return ts and tonumber(ts) and date("%Y-%m-%d %H:%M",tonumber(ts)) or "" end
local function BuildEntryPacket(e)
    return table.concat({"S",Encode(e.name),Encode(e.addedBy),tostring(e.rev or 0),Encode(e.note),Encode(e.category),Encode(e.updatedBy),tostring(e.time or 0)},"|")
end
local function BuildDeletePacket(t)
    return table.concat({"T",Encode(t.name),tostring(t.rev or 0),Encode(t.updatedBy),tostring(t.time or 0)},"|")
end
local function BuildDatabaseHash()
    local items={}
    for _,e in pairs(GuildSharedIgnoreDB.players) do if e then items[#items+1]=BuildEntryPacket(e) end end
    for _,t in pairs(GuildSharedIgnoreDB.tombstones) do if t then items[#items+1]=BuildDeletePacket(t) end end
    table.sort(items)
    local hash=2166136261
    for _,s in ipairs(items) do
        for i=1,#s do hash=(hash*16777619+s:byte(i))%2147483647 end
        hash=(hash*16777619+10)%2147483647
    end
    return tostring(hash)
end
local function BuildSyncData()
    local entries={}; local deletes={}
    for _,e in pairs(GuildSharedIgnoreDB.players) do if e then entries[#entries+1]=BuildEntryPacket(e) end end
    for _,t in pairs(GuildSharedIgnoreDB.tombstones) do if t then deletes[#deletes+1]=BuildDeletePacket(t) end end
    table.sort(entries); table.sort(deletes)
    return entries,deletes
end
local function SendChunked(kind,id,items,target)
    local chunk=""
    for _,item in ipairs(items) do
        local candidate=chunk=="" and item or chunk..","..item
        local prefix=kind.."|"..id.."|"
        if #prefix+#candidate>MAX_PACKET then
            if chunk~="" then SendAddon(prefix..chunk,target) end
            chunk=item
        else chunk=candidate end
    end
    if chunk~="" then SendAddon(kind.."|"..id.."|"..chunk,target) end
end
local function SendFullSync(id,target,requestHash)
    local entries,deletes=BuildSyncData()
    local requester=LocalName()
    local localHash=BuildDatabaseHash()
    local same=requestHash~="" and requestHash==localHash
    local entryCount=same and 0 or #entries
    local deleteCount=same and 0 or #deletes
    SendAddon("V|"..id.."|"..Encode(requester).."|"..Encode(VERSION).."|"..tostring(entryCount).."|"..tostring(deleteCount).."|"..localHash,target)
    if not same then
        SendChunked("S",id,entries,target)
        SendChunked("T",id,deletes,target)
    end
    SendAddon("E|"..id.."|"..tostring(entryCount).."|"..tostring(deleteCount),target)
end
local function ApplyEntry(name,addedBy,rev,note,category,updatedBy,ts)
    name=Normalize(name); local k=Key(name)
    if not k then return false,false end
    rev=tonumber(rev) or tonumber(ts) or 0; ts=tonumber(ts) or time(); updatedBy=Normalize(updatedBy) or Normalize(addedBy) or ""
    local e=GuildSharedIgnoreDB.players[k]; local t=GuildSharedIgnoreDB.tombstones[k]
    local tombRev=t and t.rev or 0; local tombBy=t and t.updatedBy or ""
    if not IsNewer(rev,updatedBy,tombRev,tombBy) then return false,false end
    if e and not IsNewer(rev,updatedBy,e.rev or e.time,e.updatedBy or e.addedBy) then return false,false end
    local created=not e
    GuildSharedIgnoreDB.players[k]={name=name,addedBy=Normalize(addedBy) or "",time=ts,rev=rev,note=SanitizeNote(note),category=SanitizeCategory(category),updatedBy=updatedBy}
    GuildSharedIgnoreDB.tombstones[k]=nil
    AdvanceClock(rev)
    return true,created
end
local function ApplyDelete(name,rev,updatedBy,ts)
    name=Normalize(name); local k=Key(name)
    if not k then return false end
    rev=tonumber(rev) or tonumber(ts) or 0; ts=tonumber(ts) or time(); updatedBy=Normalize(updatedBy) or ""
    local e=GuildSharedIgnoreDB.players[k]; local t=GuildSharedIgnoreDB.tombstones[k]
    if e and not IsNewer(rev,updatedBy,e.rev or e.time,e.updatedBy or e.addedBy) then return false end
    if t and not IsNewer(rev,updatedBy,t.rev or t.time,t.updatedBy) then return false end
    GuildSharedIgnoreDB.players[k]=nil
    GuildSharedIgnoreDB.tombstones[k]={name=name,time=ts,rev=rev,updatedBy=updatedBy}
    AdvanceClock(rev)
    return true
end
local function ProcessSyncBuffers()
    local imported,updated,deleted=0,0,0
    for sender,senderData in pairs(syncChunks) do
        if syncExpected[sender] and syncExpected[sender].done then
            for _,p in ipairs(senderData) do
                local name,addedBy,rev,note,category,updatedBy,ts=p:match("^S|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
                if name then
                    local changed,created=ApplyEntry(Decode(name),Decode(addedBy),rev,Decode(note),Decode(category),Decode(updatedBy),ts)
                    if changed then if created then imported=imported+1 else updated=updated+1 end end
                end
            end
        end
    end
    for sender,senderData in pairs(syncDeleteChunks) do
        if syncExpected[sender] and syncExpected[sender].done then
            for _,p in ipairs(senderData) do
                local name,rev,updatedBy,ts=p:match("^T|([^|]*)|([^|]*)|([^|]*)$")
                if name and ApplyDelete(Decode(name),rev,Decode(updatedBy),ts) then deleted=deleted+1 end
            end
        end
    end
    syncChunks={}; syncDeleteChunks={}
    if GSI.RefreshList then GSI.RefreshList() end
    return imported,updated,deleted
end
local function FinishSync(success,detail)
    if not syncActive then return end
    local imported,updated,deleted=ProcessSyncBuffers()
    syncImported=imported; syncUpdated=updated; syncDeleted=deleted
    syncActive=false
    syncLastComplete=time()
    GuildSharedIgnoreDB.lastSyncTime=syncLastComplete
    syncNextAuto=syncLastComplete+AUTO_SYNC_INTERVAL
    local responders=0
    for _ in pairs(syncResponders) do responders=responders+1 end
    local text=detail or "Full"
    if success then text=text.." • "..responders.." responder(s)" end
    UpdateSyncStatus(success and "Complete" or "Failed",text)
    if GSI.RefreshVersionDisplay then GSI.RefreshVersionDisplay() end
    if success then Print("Sync complete. "..responders.." responder(s), "..imported.." new, "..updated.." updated, "..deleted.." deleted.") end
end
local function RequestSync()
    if not IsInGuild() then UpdateSyncStatus("Failed","Not in a guild"); return false end
    if syncActive then return false end
    InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION)
    syncID=GenerateSyncID(); syncStartedAt=time(); syncResponders={}; syncExpected={}; syncChunks={}; syncDeleteChunks={}
    syncImported=0; syncUpdated=0; syncDeleted=0; syncActive=true
    UpdateSyncStatus("Syncing","Database comparison")
    local msg="Q|"..syncID.."|"..Encode(LocalName()).."|"..BuildDatabaseHash().."|"..Encode(VERSION)
    if not SendAddon(msg) then syncActive=false; UpdateSyncStatus("Failed","Addon messaging unavailable"); return false end
    if C_Timer and C_Timer.After then
        C_Timer.After(SYNC_TIMEOUT,function()
            if not syncActive or syncStartedAt<=0 then return end
            local complete=false
            for _,v in pairs(syncExpected) do if v.done then complete=true break end end
            FinishSync(complete,complete and "Full" or "Timed out; no complete responder")
        end)
    end
    return true
end
local function HandleMessage(prefix,message,distribution,sender)
    if prefix~=PREFIX or not message then return end
    sender=Normalize(sender or ""); if not sender then return end
    if Key(sender)==Key(LocalName()) then return end
    local op=message:sub(1,2)
    if op=="Q|" then
        local id,requester,hash,version=message:match("^Q|([^|]+)|([^|]*)|([^|]*)|([^|]*)$")
        if not id or not requester then return end
        RegisterAddonUser(Decode(requester),Decode(version))
        SendFullSync(id,sender,hash or "")
        return
    end
    if not syncActive then return end
    local id=message:match("^[VSTE]|([^|]+)")
    if not id or id~=syncID then return end
    if op=="V|" then
        local rid,name,version,entryCount,deleteCount,hash=message:match("^V|([^|]+)|([^|]*)|([^|]*)|(%d+)|(%d+)|([^|]*)$")
        if not rid then return end
        RegisterAddonUser(Decode(name),Decode(version))
        local sk=Key(sender)
        syncResponders[sk]=true
        syncExpected[sk]={entries=tonumber(entryCount) or 0,deletes=tonumber(deleteCount) or 0,hash=hash or "",done=false}
        return
    end
    if op=="S|" or op=="T|" then
        local rid,chunk=message:match("^[ST]|([^|]+)|(.+)$")
        if not rid or rid~=syncID then return end
        local sk=Key(sender); if not sk then return end
        syncResponders[sk]=true
        local target=op=="S|" and syncChunks or syncDeleteChunks
        target[sk]=target[sk] or {}
        for item in chunk:gmatch("([^,]+)") do target[sk][#target[sk]+1]=item end
        return
    end
    if op=="E|" then
        local rid,entryCount,deleteCount=message:match("^E|([^|]+)|(%d+)|(%d+)$")
        if not rid or rid~=syncID then return end
        local sk=Key(sender); if not sk then return end
        local expected=syncExpected[sk]
        if not expected then return end
        expected.done=true
        expected.entries=tonumber(entryCount) or expected.entries
        expected.deletes=tonumber(deleteCount) or expected.deletes
        local gotE=syncChunks[sk] and #syncChunks[sk] or 0
        local gotT=syncDeleteChunks[sk] and #syncDeleteChunks[sk] or 0
        if gotE<expected.entries or gotT<expected.deletes then expected.done=false; return end
        local allDone=true
        for _,v in pairs(syncExpected) do if not v.done then allDone=false; break end end
        if allDone then FinishSync(true,"Full") end
        return
    end
    if op=="A|" then
        local name,addedBy,ts,note,category,updatedBy,rev=message:match("^A|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if not name then name,addedBy,ts,note,category=message:match("^A|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$") end
        if not name then return end
        updatedBy=updatedBy or addedBy; rev=rev or ts
        local changed=ApplyEntry(Decode(name),Decode(addedBy),rev,Decode(note),Decode(category),Decode(updatedBy),tonumber(ts) or time())
        if changed and GSI.RefreshList then GSI.RefreshList() end
        return
    end
    if op=="N|" then
        local name,note,ts,category,updatedBy,rev=message:match("^N|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if not name then name,note,ts,category,updatedBy=message:match("^N|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$") end
        if not name then return end
        local changed=ApplyEntry(Decode(name),"",rev or ts,Decode(note),Decode(category),Decode(updatedBy),tonumber(ts) or time())
        if changed and GSI.RefreshList then GSI.RefreshList() end
        return
    end
    if op=="R|" then
        local name,by,ts,rev=message:match("^R|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        if not name then name,by,ts=message:match("^R|([^|]*)|([^|]*)|([^|]*)$") end
        if not name then return end
        local changed=ApplyDelete(Decode(name),rev or ts,Decode(by),tonumber(ts) or time())
        if changed and GSI.RefreshList then GSI.RefreshList() end
    end
end
function GSI.AddPlayer(name,note,addedBy,category)
    InitializeDB(); name=Normalize(name); if not name then return false end
    local key=Key(name); if not key then return false end
    addedBy=Normalize(addedBy or LocalName()) or LocalName(); note=SanitizeNote(note); category=SanitizeCategory(category)
    local existing=GuildSharedIgnoreDB.players[key]; local rev=NextRevision(); local ts=time()
    local e={name=name,addedBy=existing and existing.addedBy or addedBy,time=ts,rev=rev,note=note,category=category,updatedBy=addedBy}
    GuildSharedIgnoreDB.players[key]=e; GuildSharedIgnoreDB.tombstones[key]=nil
    SendAddon("A|"..Encode(name).."|"..Encode(e.addedBy).."|"..tostring(ts).."|"..Encode(note).."|"..Encode(category).."|"..Encode(addedBy).."|"..tostring(rev))
    if GSI.RefreshList then GSI.RefreshList() end
    return true
end
function GSI.RemovePlayer(name)
    InitializeDB(); name=Normalize(name); local key=Key(name); if not key or not GuildSharedIgnoreDB.players[key] then return false end
    local by=LocalName(); local rev=NextRevision(); local ts=time()
    GuildSharedIgnoreDB.players[key]=nil; GuildSharedIgnoreDB.tombstones[key]={name=name,time=ts,rev=rev,updatedBy=by}
    SendAddon("R|"..Encode(name).."|"..Encode(by).."|"..tostring(ts).."|"..tostring(rev))
    if GSI.RefreshList then GSI.RefreshList() end
    return true
end
function GSI.UpdateNote(name,note,category)
    InitializeDB(); name=Normalize(name); local key=Key(name); local e=key and GuildSharedIgnoreDB.players[key]; if not e then return false end
    note=SanitizeNote(note); category=SanitizeCategory(category or e.category); local by=LocalName(); local rev=NextRevision(); local ts=time()
    e.note=note; e.category=category; e.time=ts; e.rev=rev; e.updatedBy=by
    SendAddon("N|"..Encode(name).."|"..Encode(note).."|"..tostring(ts).."|"..Encode(category).."|"..Encode(by).."|"..tostring(rev))
    if GSI.RefreshList then GSI.RefreshList() end
    return true
end
local function ImportBlizzardIgnoreList()
    if not GetNumIgnores or not GetIgnoreName then return end
    local total=tonumber(GetNumIgnores()) or 0
    for i=1,total do
        local name=Normalize(GetIgnoreName(i)); local key=Key(name)
        if key and not GuildSharedIgnoreDB.players[key] then GSI.AddPlayer(name,"Ignore List",LocalName(),"Other") end
    end
end
local function RefreshGuildClassCache()
    guildClassCache={}
    if not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then return end
    for i=1,(GetNumGuildMembers() or 0) do
        local n,_,_,_,_,_,_,_,_,_,class=GetGuildRosterInfo(i); local k=Key(n)
        if k and class then guildClassCache[k]=class end
    end
end
local function GetClassColor(name)
    local k=Key(name); local class
    if k==Key(LocalName()) then local _,c=UnitClass("player"); class=c else class=guildClassCache[k] end
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then local c=RAID_CLASS_COLORS[class]; return c.r,c.g,c.b end
    return 1,1,1
end
local function WarnAboutGroupMember(name)
    local key=Key(name); if not key or groupWarnedPlayers[key] then return end
    local e=GuildSharedIgnoreDB.players[key]; if not e then return end
    groupWarnedPlayers[key]=true
    local msg="|cffff4444[GSI WARNING]|r "..(e.name or Normalize(name) or name).." is on the GuildSharedIgnore list"
    if e.category and e.category~="Other" then msg=msg.." ["..e.category.."]" end
    if e.note~="" then msg=msg..": "..e.note end
    Print(msg)
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then RaidNotice_AddMessage(RaidWarningFrame,"|cffff3333[GSI] "..(e.name or name).." is on the ignore list!|r",ChatTypeInfo.RAID_WARNING) end
end
local function CheckGroupMembers()
    if not IsInGroup or not IsInGroup() then groupWarnedPlayers={}; groupMembers={}; return end
    local current={}
    if IsInRaid and IsInRaid() then
        for i=1,(GetNumGroupMembers() or 0) do local u="raid"..i; if UnitExists(u) then local n=UnitName(u); local k=Key(n); if k then current[k]=true; WarnAboutGroupMember(n) end end end
    else
        for i=1,(GetNumGroupMembers() or 0) do local u="party"..i; if UnitExists(u) then local n=UnitName(u); local k=Key(n); if k then current[k]=true; WarnAboutGroupMember(n) end end end
    end
    for k in pairs(groupWarnedPlayers) do if not current[k] then groupWarnedPlayers[k]=nil end end
    groupMembers=current
end
local function GSIChatFilter(self,event,message,author,...)
    local me=Key(LocalName()); local sender=Key(author)
    if not sender or sender==me then return false end
    return IsIgnored(sender)
end
local function RegisterChatFilters()
    if chatFiltersRegistered or not ChatFrame_AddMessageEventFilter then return end
    for _,event in ipairs(chatFilterEvents) do ChatFrame_AddMessageEventFilter(event,GSIChatFilter) end
    chatFiltersRegistered=true
end
local function HandlePartyInvite(inviter)
    if not IsIgnored(inviter) then return end
    Print("|cffff4444[GSI]|r Automatically declined party invite from "..tostring(Normalize(inviter))..".")
    if DeclineGroupInvite then pcall(DeclineGroupInvite) elseif C_PartyInfo and C_PartyInfo.DeclineInvite then pcall(C_PartyInfo.DeclineInvite) end
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE"); StaticPopup_Hide("PARTY_INVITE_XREALM") end
end
function GSI.GetCategories() local t={}; for i,v in ipairs(CATEGORIES) do t[i]=v end return t end
function GSI.GetVersion() return VERSION end
function GSI.GetHighestAddonVersion() return GetHighestAddonVersion() end
function GSI.IsCurrentVersionHighest() return CompareVersions(VERSION,GetHighestAddonVersion())>=0 end
function GSI.GetAddonUsers() return GetAddonUsers() end
function GSI.CompareVersions(a,b) return CompareVersions(a,b) end
function GSI.RegisterAddonUser(n,v) RegisterAddonUser(n,v) end
function GSI.GetSyncStatus() return syncStatus,syncStatusDetail,syncActive,syncLastComplete,syncNextAuto,false,syncImported,syncUpdated,syncDeleted end
function GSI.RequestSync() return RequestSync() end
function GSI.SendAddon(msg) return SendAddon(msg) end
function GSI.GetEntry(name) return GetEntry(name) end
function GSI.IsIgnored(name) return IsIgnored(name) end
function GSI.GetPlayerName(name) local e=GetEntry(name); return e and e.name or Normalize(name) or LocalName() end
function GSI.FormatDate(ts) return FormatDate(ts) end
function GSI.Normalize(name) return Normalize(name) end
function GSI.Key(name) return Key(name) end
function GSI.GetClassColor(name) return GetClassColor(name) end
function GSI.SetSortState(column,ascending) GSI.sortColumn=column; GSI.sortAscending=ascending end
function GSI.GetSortState() return GSI.sortColumn,GSI.sortAscending end

local eventFrame=CreateFrame("Frame","GuildSharedIgnoreEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED"); eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); eventFrame:RegisterEvent("CHAT_MSG_ADDON"); eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE"); eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE"); eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
eventFrame:SetScript("OnEvent",function(self,event,...)
    if event=="ADDON_LOADED" then
        local addonName=...
        if addonName~=ADDON_NAME then return end
        InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION); RegisterChatFilters(); RefreshGuildClassCache(); ImportBlizzardIgnoreList()
        if GSI.RefreshList then GSI.RefreshList() end
        if C_Timer and C_Timer.After then
            C_Timer.After(3,function() if IsInGuild() then RefreshGuildClassCache(); CheckGroupMembers(); RequestSync() end end)
            if C_Timer.NewTicker and not autoTickerStarted then
                autoTickerStarted=true; syncNextAuto=time()+AUTO_SYNC_INTERVAL
                C_Timer.NewTicker(AUTO_SYNC_INTERVAL,function() if IsInGuild() then RequestSync() end end)
            end
        end
        Print("Loaded v"..VERSION)
    elseif event=="PLAYER_ENTERING_WORLD" then
        InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION); RegisterChatFilters()
        if C_Timer and C_Timer.After then
            C_Timer.After(2,function() RefreshGuildClassCache(); ImportBlizzardIgnoreList(); CheckGroupMembers(); if GSI.RefreshList then GSI.RefreshList() end end)
            C_Timer.After(5,function() if IsInGuild() then RequestSync() end end)
        end
    elseif event=="GUILD_ROSTER_UPDATE" then RefreshGuildClassCache(); if GSI.RefreshList then GSI.RefreshList() end
    elseif event=="GROUP_ROSTER_UPDATE" then CheckGroupMembers()
    elseif event=="PARTY_INVITE_REQUEST" then HandlePartyInvite(...)
    elseif event=="CHAT_MSG_ADDON" then HandleMessage(...)
    end
end)
SLASH_GUILDSHAREDIGNORE1="/gsi"
SlashCmdList["GUILDSHAREDIGNORE"]=function(msg)
    msg=tostring(msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if msg=="sync" then RequestSync(); return end
    if msg=="debug" then
        Print("Version: "..VERSION); Print("In guild: "..tostring(IsInGuild())); Print("Sync active: "..tostring(syncActive)); Print("Sync status: "..syncStatus.." • "..syncStatusDetail); Print("Database hash: "..BuildDatabaseHash()); Print("Responders: "..tostring((function() local n=0; for _ in pairs(syncResponders) do n=n+1 end return n end)()))
        for _,u in ipairs(GetAddonUsers()) do Print("  "..u.name.." - v"..u.version) end
        return
    end
    if msg=="version" then Print("GuildSharedIgnore v"..VERSION); Print("Highest detected version: v"..GetHighestAddonVersion()); return end
    if GSI.CreateUI then
        GSI.CreateUI()
        local f=GSI.GetFrame and GSI.GetFrame()
        if f then
            if f:IsShown() then f:Hide() else f:Show(); f:Raise(); f:EnableKeyboard(true); f:SetPropagateKeyboardInput(true); if GSI.RefreshList then GSI.RefreshList() end; if GSI.RefreshVersionDisplay then GSI.RefreshVersionDisplay() end; if GSI.RefreshSyncStatus then GSI.RefreshSyncStatus() end end
        end
    else Print("|cffff4444GuildSharedIgnore GUI is not loaded.|r") end
end
InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION); RegisterChatFilters()
