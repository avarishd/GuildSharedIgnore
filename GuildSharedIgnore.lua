local ADDON_NAME="GuildSharedIgnore"
local PREFIX="GSIgnore"
local VERSION=GetAddOnMetadata(ADDON_NAME,"Version")
local PROTOCOL=2
local MAX_PACKET=240
local SYNC_TIMEOUT=10
local AUTO_SYNC_INTERVAL=300
local ADDON_USER_TTL=86400
local MAX_CHANGE_LOG=1000
GSI=GSI or {}
local syncActive=false
local syncID=nil
local syncStartedAt=0
local syncResponders={}
local syncExpected={}
local syncIgnoredSenders={}
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
local importBatches={}
local CATEGORIES={"Toxic","Bad","Leaver","Scammer","AFK","Bad Attitude","Other"}
local CATEGORY_LOOKUP={}
for _,v in ipairs(CATEGORIES) do CATEGORY_LOOKUP[string.lower(v)]=v end
CATEGORY_LOOKUP["ignore list"]="Ignore List"
local chatFilterEvents={"CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_CHANNEL","CHAT_MSG_BATTLEGROUND","CHAT_MSG_BATTLEGROUND_LEADER"}
local function Print(msg,always)
    if not always and GuildSharedIgnoreDB and GuildSharedIgnoreDB.muteMessages then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffGuildSharedIgnore|r: "..tostring(msg)) end
end
local function Normalize(name)
    if not name then return nil end
    name=tostring(name):gsub("^%s+",""):gsub("%s+$","")
    if name=="" then return nil end
    return name
end
local function Key(name)
    name=Normalize(name)
    return name and string.lower(name) or nil
end
local function ClassKey(name)
    local key=Key(name)
    return key and (key:match("^([^%-]+)") or key) or nil
end
local function Encode(s)
    s=tostring(s or "")
    return s:gsub("%%","%%25"):gsub("|","%%7C"):gsub(";","%%3B"):gsub(",","%%2C"):gsub("\r","%%0D"):gsub("\n","%%0A")
end
local function Decode(s)
    s=tostring(s or "")
    return s:gsub("%%0A","\n"):gsub("%%0D","\r"):gsub("%%2C",","):gsub("%%3B",";"):gsub("%%7C","|"):gsub("%%25","%%")
end
local function SanitizeCategory(category) category=tostring(category or "Other"); return CATEGORY_LOOKUP[string.lower(category)] or "Other" end
local function SanitizeNote(note) note=tostring(note or ""):gsub("\r"," "):gsub("\n"," "); if #note>255 then note=note:sub(1,255) end; return note end
local function LocalName() return Normalize(UnitName("player")) or "Unknown" end
local function IsLocalSender(sender)
    local senderName,senderRealm=tostring(sender or ""):match("^([^-]+)%-(.+)$")
    if not senderName then return Key(sender)==Key(LocalName()) end
    if Key(senderName)~=Key(LocalName()) then return false end
    local localRealm=GetRealmName and GetRealmName() or ""
    local function RealmKey(realm)
        return tostring(realm or ""):lower():gsub("[%s%-']", "")
    end
    return localRealm~="" and RealmKey(senderRealm)==RealmKey(localRealm)
end
local function GetMajorVersion(version)
    local major=tostring(version or "0"):match("^(%d+)")
    return tonumber(major) or 0
end

local function ResetGuildSharedIgnoreDatabase()
    local defaults={
        players={},
        tombstones={},
        characterClasses={},
        changeLog={},
        logicalClock=0,
        databaseRevision=0,
        lastSyncTime=0,
        protocol=PROTOCOL,
        announceGuild=false,
        muteMessages=true,
        confirmDelete=true,
        guiAlpha=1,
        _version=VERSION
    }
    for key,value in pairs(defaults) do
        GuildSharedIgnoreDB[key]=value
    end
    if GSI and GSI.RefreshList then GSI.RefreshList() end
    Print("Database reset for new major version v"..VERSION..".")
end

local function InitializeDB()
    GuildSharedIgnoreDB=GuildSharedIgnoreDB or {}

    local previousVersion=GuildSharedIgnoreDB._version or GuildSharedIgnoreDB.version
    local previousMajor=GetMajorVersion(previousVersion)
    local currentMajor=GetMajorVersion(VERSION)
    local hasLegacyData=(GuildSharedIgnoreDB.players and next(GuildSharedIgnoreDB.players)~=nil) or (GuildSharedIgnoreDB.tombstones and next(GuildSharedIgnoreDB.tombstones)~=nil) or (GuildSharedIgnoreDB.changeLog and #GuildSharedIgnoreDB.changeLog>0)
    if previousVersion and previousMajor~=0 and currentMajor>previousMajor then
        ResetGuildSharedIgnoreDatabase()
    elseif previousVersion==nil and hasLegacyData then
        ResetGuildSharedIgnoreDatabase()
    end

    GuildSharedIgnoreDB.players=GuildSharedIgnoreDB.players or {}
    GuildSharedIgnoreDB.tombstones=GuildSharedIgnoreDB.tombstones or {}
    GuildSharedIgnoreDB.characterClasses=GuildSharedIgnoreDB.characterClasses or {}
    if type(GuildSharedIgnoreDB.characterClasses)~="table" then GuildSharedIgnoreDB.characterClasses={} end
    GuildSharedIgnoreDB.changeLog=GuildSharedIgnoreDB.changeLog or {}
    GuildSharedIgnoreDB.logicalClock=tonumber(GuildSharedIgnoreDB.logicalClock) or 0
    GuildSharedIgnoreDB.databaseRevision=tonumber(GuildSharedIgnoreDB.databaseRevision) or 0
    GuildSharedIgnoreDB.lastSyncTime=tonumber(GuildSharedIgnoreDB.lastSyncTime) or 0
    GuildSharedIgnoreDB.protocol=PROTOCOL
    if GuildSharedIgnoreDB.announceGuild==nil then GuildSharedIgnoreDB.announceGuild=false end
    if GuildSharedIgnoreDB.muteMessages==nil then GuildSharedIgnoreDB.muteMessages=true end
    if GuildSharedIgnoreDB.confirmDelete==nil then GuildSharedIgnoreDB.confirmDelete=true end
    if GuildSharedIgnoreDB.guiAlpha==nil then GuildSharedIgnoreDB.guiAlpha=1 end
    GuildSharedIgnoreDB._version=VERSION
    local maxRevision=GuildSharedIgnoreDB.logicalClock
    for key,e in pairs(GuildSharedIgnoreDB.players) do
        if e then
            e.name=Normalize(e.name or key) or key
            e.addedBy=Normalize(e.addedBy or "") or ""
            e.note=SanitizeNote(e.note)
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
    if maxRevision>GuildSharedIgnoreDB.logicalClock then GuildSharedIgnoreDB.logicalClock=maxRevision end
end
local function NextRevision()
    InitializeDB()
    local r=(tonumber(GuildSharedIgnoreDB.logicalClock) or 0)+1
    GuildSharedIgnoreDB.logicalClock=r
    GuildSharedIgnoreDB.databaseRevision=(tonumber(GuildSharedIgnoreDB.databaseRevision) or 0)+1
    return r
end
local function AdvanceClock(rev)
    rev=tonumber(rev) or 0; InitializeDB()
    if rev>GuildSharedIgnoreDB.logicalClock then GuildSharedIgnoreDB.logicalClock=rev end
end
local function CompareVersions(a,b)
    local function p(v) local x,y,z=tostring(v or "0"):match("^(%d+)%.(%d+)%.?(%d*)"); return tonumber(x) or 0,tonumber(y) or 0,tonumber(z) or 0 end
    local a1,a2,a3=p(a); local b1,b2,b3=p(b)
    if a1~=b1 then return a1>b1 and 1 or -1 end
    if a2~=b2 then return a2>b2 and 1 or -1 end
    if a3~=b3 then return a3>b3 and 1 or -1 end
    return 0
end
local NotifyIfAddonOutdated
local function RegisterAddonUser(name,version,protocol)
    name=Normalize(name); version=tostring(version or ""); protocol=tonumber(protocol) or 0
    if not name or version=="" then return end
    addonUsers[Key(name)]={name=name,version=version,protocol=protocol,lastSeen=time()}
    NotifyIfAddonOutdated()
end
local function PruneAddonUsers()
    local now=time()
    for key,u in pairs(addonUsers) do if not u or not u.lastSeen or now-u.lastSeen>ADDON_USER_TTL then addonUsers[key]=nil end end
end
local function GetAddonUsers()
    PruneAddonUsers(); local out={}
    for _,u in pairs(addonUsers) do if u then out[#out+1]={name=u.name,version=u.version,protocol=u.protocol,lastSeen=u.lastSeen} end end
    table.sort(out,function(a,b) local c=CompareVersions(a.version,b.version); if c~=0 then return c>0 end return string.lower(a.name)<string.lower(b.name) end)
    return out
end
local function GetHighestAddonVersion()
    local high=VERSION
    for _,u in ipairs(GetAddonUsers()) do if CompareVersions(u.version,high)>0 then high=u.version end end
    return high
end
local outdatedWarningShown=false
NotifyIfAddonOutdated=function()
    if outdatedWarningShown then return end
    local highestVersion=GetHighestAddonVersion()
    if not highestVersion or CompareVersions(VERSION,highestVersion)>=0 then return end
    if GuildSharedIgnoreDB and GuildSharedIgnoreDB.muteMessages then return end
    outdatedWarningShown=true
    Print("Your GuildSharedIgnore addon is outdated. Please update to v"..tostring(highestVersion)..".")
end
local function RefreshStatus() if GSI.RefreshSyncStatus then GSI.RefreshSyncStatus() end end
local function UpdateSyncStatus(status,detail) syncStatus=status or "Idle"; syncStatusDetail=detail or ""; RefreshStatus() end
local function RegisterPrefix()
    if RegisterAddonMessagePrefix then return RegisterAddonMessagePrefix(PREFIX)~=false end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then return C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)~=false end
    return false
end
local function SendAddon(msg,target)
    if not msg or #msg>255 then return false end
    if SendAddonMessage then SendAddonMessage(PREFIX,msg,target and "WHISPER" or "GUILD",target); return true end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(PREFIX,msg,target and "WHISPER" or "GUILD",target); return true end
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
local function GetEntry(name) local k=Key(name); return k and GuildSharedIgnoreDB.players[k] or nil end
local function IsIgnored(name) return GetEntry(name)~=nil end
local function FormatDate(ts) return ts and tonumber(ts) and date("%Y-%m-%d %H:%M",tonumber(ts)) or "" end
local function BuildEntryPacket(e)
    return table.concat({"S",Encode(e.name),Encode(e.addedBy),tostring(e.rev or 0),Encode(e.note),Encode(e.category),Encode(e.updatedBy),tostring(e.time or 0)} ,"|")
end
local function BuildDeletePacket(t) return table.concat({"T",Encode(t.name),tostring(t.rev or 0),Encode(t.updatedBy),tostring(t.time or 0)},"|") end
local function HashString(s)
    local hash=2166136261
    for i=1,#s do hash=(hash*16777619+s:byte(i))%2147483647 end
    return tostring(hash)
end
local function BuildDatabaseHash()
    local items={}
    for _,e in pairs(GuildSharedIgnoreDB.players) do if e then items[#items+1]=BuildEntryPacket(e) end end
    for _,t in pairs(GuildSharedIgnoreDB.tombstones) do if t then items[#items+1]=BuildDeletePacket(t) end end
    table.sort(items); return HashString(table.concat(items,"\n"))
end
local function AppendChange(packet,loggedAt)
    InitializeDB(); local log=GuildSharedIgnoreDB.changeLog
    log[#log+1]={packet=packet,time=tonumber(loggedAt) or time()}
    while #log>MAX_CHANGE_LOG do table.remove(log,1) end
end
local function BuildChangeSet(since)
    since=tonumber(since) or 0; local entries={}; local deletes={}; local earliest=nil
    for _,c in ipairs(GuildSharedIgnoreDB.changeLog) do
        if c and c.packet then
            earliest=earliest or tonumber(c.time) or 0
            if (tonumber(c.time) or 0)>since then
                if c.packet:sub(1,2)=="S|" then entries[#entries+1]=c.packet else deletes[#deletes+1]=c.packet end
            end
        end
    end
    table.sort(entries); table.sort(deletes)
    return entries,deletes,earliest
end
local function BuildFullSet()
    local entries,deletes={},{ }
    for _,e in pairs(GuildSharedIgnoreDB.players) do if e then entries[#entries+1]=BuildEntryPacket(e) end end
    for _,t in pairs(GuildSharedIgnoreDB.tombstones) do if t then deletes[#deletes+1]=BuildDeletePacket(t) end end
    table.sort(entries); table.sort(deletes); return entries,deletes
end
local function SendChunked(kind,id,items,target)
    if #items==0 then return 0 end
    local chunks={}; local chunk=""
    local function flush() if chunk~="" then chunks[#chunks+1]=chunk; chunk="" end end
    for _,item in ipairs(items) do
        local candidate=chunk=="" and item or chunk..","..item
        if #("D|"..id.."|"..kind.."|999|999|999999999|")+ #candidate>MAX_PACKET then
            if chunk=="" then return 0 end
            flush(); chunk=item
        else chunk=candidate end
    end
    flush()
    local total=#chunks
    for i,payload in ipairs(chunks) do SendAddon("D|"..id.."|"..kind.."|"..i.."|"..total.."|"..HashString(payload).."|"..payload,target) end
    return total
end
local function SendSyncResponse(id,target,requestHash,requestLastSync)
    local localHash=BuildDatabaseHash(); local mode="none"; local entries,deletes={},{}
    if requestHash~=localHash then
        local deltaE,deltaT,earliest=BuildChangeSet(requestLastSync)
        if #GuildSharedIgnoreDB.changeLog>0 and (tonumber(requestLastSync) or 0)>=((earliest or 0)-1) and (#deltaE+#deltaT)>0 then entries,deletes=deltaE,deltaT; mode="delta" else entries,deletes=BuildFullSet(); mode="full" end
    end
    local ec=#entries; local dc=#deletes
    SendAddon("V|"..PROTOCOL.."|"..id.."|"..Encode(LocalName()).."|"..Encode(VERSION).."|"..mode.."|"..ec.."|"..dc.."|"..localHash,target)
    local et=SendChunked("S",id,entries,target); local dt=SendChunked("T",id,deletes,target)
    SendAddon("E|"..id.."|"..mode.."|"..ec.."|"..dc.."|"..et.."|"..dt.."|"..localHash,target)
end
local function ApplyEntry(name,addedBy,rev,note,category,updatedBy,ts,recordChange)
    name=Normalize(name); local k=Key(name); if not k then return false,false end
    rev=tonumber(rev) or tonumber(ts) or 0; ts=tonumber(ts) or time(); addedBy=Normalize(addedBy) or ""; updatedBy=Normalize(updatedBy) or addedBy or ""
    local e=GuildSharedIgnoreDB.players[k]; local t=GuildSharedIgnoreDB.tombstones[k]
    if t and not IsNewer(rev,updatedBy,t.rev,t.updatedBy) then return false,false end
    if e and not IsNewer(rev,updatedBy,e.rev,e.updatedBy) then return false,false end
    if e and e.addedBy and e.addedBy~="" then addedBy=e.addedBy end
    local created=not e
    GuildSharedIgnoreDB.players[k]={name=name,addedBy=addedBy,time=ts,rev=rev,note=SanitizeNote(note),category=SanitizeCategory(category),updatedBy=updatedBy}
    GuildSharedIgnoreDB.tombstones[k]=nil; AdvanceClock(rev)
    if recordChange then AppendChange(BuildEntryPacket(GuildSharedIgnoreDB.players[k]),time()) end
    return true,created
end
local function ApplyDelete(name,rev,updatedBy,ts,recordChange)
    name=Normalize(name); local k=Key(name); if not k then return false end
    rev=tonumber(rev) or tonumber(ts) or 0; ts=tonumber(ts) or time(); updatedBy=Normalize(updatedBy) or ""
    local e=GuildSharedIgnoreDB.players[k]; local t=GuildSharedIgnoreDB.tombstones[k]
    if e and not IsNewer(rev,updatedBy,e.rev,e.updatedBy) then return false end
    if t and not IsNewer(rev,updatedBy,t.rev,t.updatedBy) then return false end
    GuildSharedIgnoreDB.players[k]=nil; GuildSharedIgnoreDB.tombstones[k]={name=name,time=ts,rev=rev,updatedBy=updatedBy}; AdvanceClock(rev)
    if recordChange then AppendChange(BuildDeletePacket(GuildSharedIgnoreDB.tombstones[k]),time()) end
    return true
end
local function ProcessSyncBuffers()
    local imported,updated,deleted=0,0,0
    for sender,data in pairs(syncExpected) do
        if data.complete then
            local parts={}
            for i=1,data.entryTotal do parts[i]=data.entries[i] end
            for i=1,data.deleteTotal do data.deletes[i]=data.deletes[i] end
            for i=1,data.entryTotal do local p=parts[i]; if p then local n,a,r,no,c,u,t=p:match("^S|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then local ch,cr=ApplyEntry(Decode(n),Decode(a),r,Decode(no),Decode(c),Decode(u),t,true); if ch then if cr then imported=imported+1 else updated=updated+1 end end end end end
            for i=1,data.deleteTotal do local p=data.deletes[i]; if p then local n,r,u,t=p:match("^T|([^|]*)|([^|]*)|([^|]*)$"); if n and ApplyDelete(Decode(n),r,Decode(u),t,true) then deleted=deleted+1 end end end
        end
    end
    syncChunks={}; syncDeleteChunks={}; if GSI.RefreshList then GSI.RefreshList() end
    return imported,updated,deleted
end
local function CountResponders() local n=0; for _ in pairs(syncResponders) do n=n+1 end; return n end
local function FinishSync(success,detail)
    if not syncActive then return end
    local imported,updated,deleted=ProcessSyncBuffers(); syncImported=imported; syncUpdated=updated; syncDeleted=deleted
    local complete=0; local partial=0
    for _,v in pairs(syncExpected) do if v.complete then complete=complete+1 else partial=partial+1 end end
    local responders=CountResponders()
    syncActive=false; syncLastComplete=time(); GuildSharedIgnoreDB.lastSyncTime=syncLastComplete; syncNextAuto=syncLastComplete+AUTO_SYNC_INTERVAL
    local text=detail or "Complete"
    if success then
        text=text.." • "..responders.." responder(s)"
        if partial>0 then text=text.." • "..complete.." complete, "..partial.." incomplete" end
    end
    UpdateSyncStatus(success and "Complete" or "Failed",text)
    if GSI.RefreshVersionDisplay then GSI.RefreshVersionDisplay() end
    if success then
        NotifyIfAddonOutdated()
        Print("Sync complete. "..responders.." responder(s), "..complete.." complete, "..partial.." incomplete; "..imported.." new, "..updated.." updated, "..deleted.." deleted.")
    end
end
local function AllExpectedComplete()
    local any=false
    for _,v in pairs(syncExpected) do any=true; if not v.complete then return false end end
    return any
end
local function RequestSync()
    if not IsInGuild() then UpdateSyncStatus("Failed","Not in a guild"); return false end
    if syncActive then return false end
    InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION,PROTOCOL)
    syncID=GenerateSyncID(); syncStartedAt=time(); syncResponders={}; syncExpected={}; syncIgnoredSenders={}; syncChunks={}; syncDeleteChunks={}; syncImported=0; syncUpdated=0; syncDeleted=0; syncActive=true
    UpdateSyncStatus("Syncing","Database comparison")
    local msg="Q|"..PROTOCOL.."|"..syncID.."|"..Encode(LocalName()).."|"..BuildDatabaseHash().."|"..Encode(VERSION).."|"..tostring(GuildSharedIgnoreDB.lastSyncTime or 0)
    if not SendAddon(msg) then syncActive=false; UpdateSyncStatus("Failed","Addon messaging unavailable"); return false end
    if C_Timer and C_Timer.After then C_Timer.After(SYNC_TIMEOUT,function() if not syncActive then return end; if AllExpectedComplete() then FinishSync(true,"Complete") elseif CountResponders()>0 then FinishSync(true,"Partial") else FinishSync(false,"Timed out; no compatible responder • 0 responders") end end) end
    return true
end
local function HandleChunk(sender,rid,kind,seq,total,checksum,payload)
    if not syncActive or rid~=syncID then return end
    local sk=Key(sender); local d=syncExpected[sk]
    if not d then d={entries={},deletes={},entryChunks=nil,deleteChunks=nil,entryTotal=0,deleteTotal=0,complete=false,invalid=false,preV=true}; syncExpected[sk]=d; syncResponders[sk]=true end
    seq=tonumber(seq); total=tonumber(total); if not seq or not total or seq<1 or seq>total then return end
    if HashString(payload or "")~=checksum then d.invalid=true; return end
    local target=kind=="S" and d.entries or d.deletes; local expectedTotal=kind=="S" and d.entryChunks or d.deleteChunks
    if expectedTotal and expectedTotal~=total then d.invalid=true; return end
    if kind=="S" then d.entryChunks=total else d.deleteChunks=total end
    target[seq]=payload
end
local function FinalizeResponder(sender,rid,mode,ec,dc,et,dt,hash)
    if not syncActive or rid~=syncID then return end
    local sk=Key(sender); local d=syncExpected[sk]
    if not d then d={entries={},deletes={},entryChunks=nil,deleteChunks=nil,entryTotal=0,deleteTotal=0,complete=false,invalid=false,preV=true}; syncExpected[sk]=d; syncResponders[sk]=true end
    d.mode=mode; d.entryTotal=tonumber(ec) or 0; d.deleteTotal=tonumber(dc) or 0; d.entryChunks=tonumber(et) or 0; d.deleteChunks=tonumber(dt) or 0; d.hash=hash or d.hash
    if d.invalid then return end
    if d.entryChunks~=#d.entries or d.deleteChunks~=#d.deletes then return end
    for i=1,d.entryChunks do if not d.entries[i] then return end end
    for i=1,d.deleteChunks do if not d.deletes[i] then return end end
    local flatE={}; for i=1,d.entryChunks do for item in d.entries[i]:gmatch("([^,]+)") do flatE[#flatE+1]=item end end
    local flatT={}; for i=1,d.deleteChunks do for item in d.deletes[i]:gmatch("([^,]+)") do flatT[#flatT+1]=item end end
    if #flatE~=d.entryTotal or #flatT~=d.deleteTotal then d.invalid=true; return end
    d.entries=flatE; d.deletes=flatT; d.complete=true; syncResponders[sk]=true
    if AllExpectedComplete() then FinishSync(true,mode=="delta" and "Incremental" or "Full") end
end
local function HandleMessage(prefix,message,distribution,sender)
    if prefix~=PREFIX or not message then return end
    sender=Normalize(sender or ""); if not sender or IsLocalSender(sender) then return end
    local op=message:sub(1,2)
    if op=="Q|" then
        local protocol,id,requester,hash,version,lastSync=message:match("^Q|(%d+)|([^|]+)|([^|]*)|([^|]*)|([^|]*)|(%d+)$")
        if not protocol then return end
        protocol=tonumber(protocol); RegisterAddonUser(Decode(requester),Decode(version),protocol)
        if protocol~=PROTOCOL then SendAddon("X|"..tostring(protocol).."|"..Encode(VERSION).."|"..PROTOCOL,sender); return end
        SendSyncResponse(id,sender,hash or "",tonumber(lastSync) or 0); return
    end
    if op=="X|" then local p,v,supported=message:match("^X|(%d+)|([^|]*)|(%d+)$"); RegisterAddonUser(sender,Decode(v),tonumber(p)); Print("Incompatible GuildSharedIgnore protocol from "..sender.." (peer "..tostring(p)..", local "..tostring(supported)..")."); return end
    if op=="B|" then
        local id,seq,total,checksum,payload=message:match("^B|([^|]+)|(%d+)|(%d+)|([^|]+)|(.+)$")
        if not id then return end
        local b=importBatches[id] or {total=tonumber(total),chunks={}}; importBatches[id]=b; seq=tonumber(seq); total=tonumber(total)
        if not seq or not total or HashString(payload or "")~=checksum then importBatches[id]=nil; return end
        b.total=total; b.chunks[seq]=payload
        local ready=true; for i=1,total do if not b.chunks[i] then ready=false; break end end
        if ready then
            for i=1,total do for item in b.chunks[i]:gmatch("([^;]+)") do local n,a,r,no,c,u,t=item:match("^S|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then ApplyEntry(Decode(n),Decode(a),r,Decode(no),Decode(c),Decode(u),t,true) end end end
            importBatches[id]=nil; if GSI.RefreshList then GSI.RefreshList() end
        end
        return
    end
    if not syncActive then
        if op=="A|" or op=="N|" or op=="R|" then
            if op=="A|" then local n,a,t,no,c,u,r=message:match("^A|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then ApplyEntry(Decode(n),Decode(a),r,Decode(no),Decode(c),Decode(u),t,true) end
            elseif op=="N|" then local n,no,t,c,u,r=message:match("^N|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then local e=GetEntry(Decode(n)); local a=e and e.addedBy or ""; ApplyEntry(Decode(n),a,r,Decode(no),Decode(c),Decode(u),t,true) end
            else local n,b,t,r=message:match("^R|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then ApplyDelete(Decode(n),r,Decode(b),t,true) end end
            if GSI.RefreshList then GSI.RefreshList() end
        end
        return
    end
    if op=="V|" then
        local protocol,rid,name,version,mode,ec,dc,hash=message:match("^V|(%d+)|([^|]+)|([^|]*)|([^|]*)|([^|]*)|(%d+)|(%d+)|([^|]*)$")
        if not protocol or tonumber(protocol)~=PROTOCOL or rid~=syncID then return end
        local peerName=Decode(name)
        if Key(peerName)==Key(LocalName()) then syncIgnoredSenders[Key(sender)]=true; return end
        local sk=Key(sender); RegisterAddonUser(Decode(name),Decode(version),tonumber(protocol)); syncResponders[sk]=true
        local d=syncExpected[sk] or {}
        d.entries=d.entries or {}; d.deletes=d.deletes or {}; d.entryChunks=d.entryChunks or 0; d.deleteChunks=d.deleteChunks or 0; d.entryTotal=tonumber(ec) or 0; d.deleteTotal=tonumber(dc) or 0; d.hash=hash or ""; d.complete=false; d.invalid=d.invalid or false; d.mode=mode; syncExpected[sk]=d
        return
    end
    if op=="D|" then
        if syncIgnoredSenders[Key(sender)] then return end
        local rid,kind,seq,total,checksum,payload=message:match("^D|([^|]+)|([ST])|(%d+)|(%d+)|([^|]+)|(.+)$")
        if rid then HandleChunk(sender,rid,kind,seq,total,checksum,payload) end
        return
    end
    if op=="E|" then
        if syncIgnoredSenders[Key(sender)] then return end
        local rid,mode,ec,dc,et,dt,hash=message:match("^E|([^|]+)|([^|]*)|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)$")
        if rid then FinalizeResponder(sender,rid,mode,ec,dc,et,dt,hash) end
        return
    end
    if op=="A|" then local n,a,t,no,c,u,r=message:match("^A|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then local ch=ApplyEntry(Decode(n),Decode(a),r,Decode(no),Decode(c),Decode(u),t,true); if ch and GSI.RefreshList then GSI.RefreshList() end end; return end
    if op=="N|" then local n,no,t,c,u,r=message:match("^N|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then local e=GetEntry(Decode(n)); local a=e and e.addedBy or ""; local ch=ApplyEntry(Decode(n),a,r,Decode(no),Decode(c),Decode(u),t,true); if ch and GSI.RefreshList then GSI.RefreshList() end end; return end
    if op=="R|" then local n,b,t,r=message:match("^R|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"); if n then local ch=ApplyDelete(Decode(n),r,Decode(b),t,true); if ch and GSI.RefreshList then GSI.RefreshList() end end end
end
function GSI.AddPlayer(name,note,addedBy,category,broadcast)
    InitializeDB(); name=Normalize(name); local key=Key(name); if not key then return false,"invalid" end
    addedBy=Normalize(addedBy or LocalName()) or LocalName(); note=SanitizeNote(note); category=SanitizeCategory(category)
    local existing=GuildSharedIgnoreDB.players[key]; local rev=NextRevision(); local ts=time(); local originalAddedBy=existing and existing.addedBy or addedBy
    local e={name=name,addedBy=originalAddedBy,time=ts,rev=rev,note=note,category=category,updatedBy=addedBy}
    GuildSharedIgnoreDB.players[key]=e; GuildSharedIgnoreDB.tombstones[key]=nil; local packet="A|"..Encode(name).."|"..Encode(originalAddedBy).."|"..tostring(ts).."|"..Encode(note).."|"..Encode(category).."|"..Encode(addedBy).."|"..tostring(rev); AppendChange(BuildEntryPacket(e),time())
    if broadcast~=false then SendAddon(packet) end
    if GSI.RefreshList then GSI.RefreshList() end
    return true,existing and "updated" or "added"
end
function GSI.RemovePlayer(name)
    InitializeDB(); name=Normalize(name); local key=Key(name); if not key or not GuildSharedIgnoreDB.players[key] then return false end
    local by=LocalName(); local rev=NextRevision(); local ts=time(); GuildSharedIgnoreDB.players[key]=nil; GuildSharedIgnoreDB.tombstones[key]={name=name,time=ts,rev=rev,updatedBy=by}; AppendChange(BuildDeletePacket(GuildSharedIgnoreDB.tombstones[key]),time()); SendAddon("R|"..Encode(name).."|"..Encode(by).."|"..tostring(ts).."|"..tostring(rev)); if GSI.RefreshList then GSI.RefreshList() end; return true
end
function GSI.UpdateNote(name,note,category)
    InitializeDB(); name=Normalize(name); local key=Key(name); local e=key and GuildSharedIgnoreDB.players[key]; if not e then return false end
    note=SanitizeNote(note); category=SanitizeCategory(category or e.category); local by=LocalName(); local rev=NextRevision(); local ts=time(); e.note=note; e.category=category; e.time=ts; e.rev=rev; e.updatedBy=by; AppendChange(BuildEntryPacket(e),time()); SendAddon("N|"..Encode(name).."|"..Encode(note).."|"..tostring(ts).."|"..Encode(category).."|"..Encode(by).."|"..tostring(rev)); if GSI.RefreshList then GSI.RefreshList() end; return true
end
local function SendImportBatch(items)
    if #items==0 then return end
    local id="import_"..GenerateSyncID(); local payload=""; local chunks={}
    for _,item in ipairs(items) do
        local candidate=payload=="" and item or payload..";"..item
        if #("B|"..id.."|999|999|999999999|")+ #candidate>MAX_PACKET then if payload~="" then chunks[#chunks+1]=payload end; payload=item else payload=candidate end
    end
    if payload~="" then chunks[#chunks+1]=payload end
    for i,p in ipairs(chunks) do SendAddon("B|"..id.."|"..i.."|"..#chunks.."|"..HashString(p).."|"..p) end
end
local function ImportBlizzardIgnoreList()
    if not GetNumIgnores or not GetIgnoreName then return end
    InitializeDB(); local total=tonumber(GetNumIgnores()) or 0; local imported={}; local ignored={}; local importCount=0
    for i=1,total do
        local name=Normalize(GetIgnoreName(i)); local key=Key(name)
        if key then
            ignored[key]=name
            local entry=GuildSharedIgnoreDB.players[key]
            local isLegacyImport=entry and entry.category=="Other" and entry.note=="Ignore List"
            if not entry or isLegacyImport then
                local addedBy=entry and entry.addedBy or LocalName()
                local ok=GSI.AddPlayer(name,"",addedBy,"Ignore List",false)
                if ok then local updated=GuildSharedIgnoreDB.players[key]; if updated then imported[#imported+1]=BuildEntryPacket(updated); importCount=importCount+1 end end
            end
        end
    end
    local localName=Key(LocalName())
    for key,entry in pairs(GuildSharedIgnoreDB.players) do
        local isLegacyImport=entry and entry.category=="Other" and entry.note=="Ignore List"
        if entry and (entry.category=="Ignore List" or isLegacyImport) and Key(entry.addedBy)==localName and not ignored[key] then
            GSI.RemovePlayer(entry.name)
        end
    end
    SendImportBatch(imported)
    if importCount>0 then Print("Imported "..importCount.." player(s) from the Blizzard ignore list.") end
    if GSI.RefreshList then GSI.RefreshList() end
end
local function RefreshGuildClassCache()
    guildClassCache={}; if not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then return end
    for i=1,(GetNumGuildMembers(true) or 0) do local n,_,_,_,_,_,_,_,_,_,class=GetGuildRosterInfo(i); local k=Key(n); local classKey=ClassKey(n); if class and k then guildClassCache[k]=class; if classKey then guildClassCache[classKey]=class end end end
end
local function RememberLocalClass()
    local name=UnitName("player"); local classKey=ClassKey(name); local _,class=UnitClass("player")
    if classKey and class then GuildSharedIgnoreDB.characterClasses[classKey]=class end
end
local function GetClassColor(name)
    local k=Key(name); local classKey=ClassKey(name); local class
    if classKey==ClassKey(LocalName()) then local _,c=UnitClass("player"); class=c
    else class=(k and guildClassCache[k]) or (classKey and guildClassCache[classKey]) or (classKey and GuildSharedIgnoreDB.characterClasses[classKey]) end
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then local c=RAID_CLASS_COLORS[class]; return c.r,c.g,c.b end
    return 1,1,1
end
local function WarnAboutGroupMember(name)
    local key=Key(name); if not key or groupWarnedPlayers[key] then return end; local e=GuildSharedIgnoreDB.players[key]; if not e then return end
    groupWarnedPlayers[key]=true; local msg="|cffff4444[GSI WARNING]|r "..(e.name or name).." is on the GuildSharedIgnore list"; if e.category~="Other" then msg=msg.." ["..e.category.."]" end; if e.note~="" then msg=msg..": "..e.note end; Print(msg,true)
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then RaidNotice_AddMessage(RaidWarningFrame,"|cffff3333[GSI] "..(e.name or name).." is on the ignore list!|r",ChatTypeInfo.RAID_WARNING) end
end
local function CheckGroupMembers()
    if not IsInGroup or not IsInGroup() then groupWarnedPlayers={}; groupMembers={}; return end
    local current={}; local raid=IsInRaid and IsInRaid(); local prefix=raid and "raid" or "party"
    for i=1,(GetNumGroupMembers() or 0) do local u=prefix..i; if UnitExists(u) then local n=UnitName(u); local k=Key(n); if k then current[k]=true; WarnAboutGroupMember(n) end end end
    for k in pairs(groupWarnedPlayers) do if not current[k] then groupWarnedPlayers[k]=nil end end; groupMembers=current
end
local function GSIChatFilter(self,event,message,author,...) local sender=Key(author); if not sender or sender==Key(LocalName()) then return false end; return IsIgnored(sender) end
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
function GSI.GetCategories() local t={}; for i,v in ipairs(CATEGORIES) do t[i]=v end; return t end
function GSI.GetVersion() return VERSION end
function GSI.GetProtocol() return PROTOCOL end
function GSI.GetHighestAddonVersion() return GetHighestAddonVersion() end
function GSI.IsCurrentVersionHighest() return CompareVersions(VERSION,GetHighestAddonVersion())>=0 end
function GSI.GetAddonUsers() return GetAddonUsers() end
function GSI.CompareVersions(a,b) return CompareVersions(a,b) end
function GSI.RegisterAddonUser(n,v,p) RegisterAddonUser(n,v,p) end
function GSI.GetSyncStatus() return syncStatus,syncStatusDetail,syncActive,syncLastComplete,syncNextAuto,true,syncImported,syncUpdated,syncDeleted end
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
eventFrame:RegisterEvent("ADDON_LOADED"); eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); eventFrame:RegisterEvent("CHAT_MSG_ADDON"); eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE"); eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE"); eventFrame:RegisterEvent("PARTY_INVITE_REQUEST"); eventFrame:RegisterEvent("IGNORELIST_UPDATE")
eventFrame:SetScript("OnEvent",function(self,event,...)
    if event=="ADDON_LOADED" then
        local addonName=...; if addonName~=ADDON_NAME then return end
        InitializeDB(); RememberLocalClass(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION,PROTOCOL); RegisterChatFilters(); RefreshGuildClassCache(); ImportBlizzardIgnoreList(); if GSI.RefreshList then GSI.RefreshList() end
        if C_Timer and C_Timer.After then
            C_Timer.After(3,function() if IsInGuild() then RefreshGuildClassCache(); CheckGroupMembers(); RequestSync() end end)
            if C_Timer.NewTicker and not autoTickerStarted then autoTickerStarted=true; syncNextAuto=time()+AUTO_SYNC_INTERVAL; C_Timer.NewTicker(AUTO_SYNC_INTERVAL,function() if IsInGuild() then RequestSync() end end) end
        end
        Print("Loaded v"..VERSION)
    elseif event=="PLAYER_ENTERING_WORLD" then
        InitializeDB(); RememberLocalClass(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION,PROTOCOL); RegisterChatFilters()
        if C_Timer and C_Timer.After then C_Timer.After(2,function() RefreshGuildClassCache(); ImportBlizzardIgnoreList(); CheckGroupMembers(); if GSI.RefreshList then GSI.RefreshList() end end); C_Timer.After(5,function() if IsInGuild() then RequestSync() end end) end
    elseif event=="GUILD_ROSTER_UPDATE" then RefreshGuildClassCache(); if GSI.RefreshList then GSI.RefreshList() end
    elseif event=="IGNORELIST_UPDATE" then ImportBlizzardIgnoreList()
    elseif event=="GROUP_ROSTER_UPDATE" then CheckGroupMembers()
    elseif event=="PARTY_INVITE_REQUEST" then HandlePartyInvite(...)
    elseif event=="CHAT_MSG_ADDON" then HandleMessage(...)
    end
end)
SLASH_GUILDSHAREDIGNORE1="/gsi"
SlashCmdList["GUILDSHAREDIGNORE"]=function(msg)
    msg=tostring(msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if msg=="sync" then RequestSync(); return end
    if msg=="debug" then Print("Version: "..VERSION.." / Protocol: "..PROTOCOL); Print("In guild: "..tostring(IsInGuild())); Print("Sync active: "..tostring(syncActive)); Print("Sync status: "..syncStatus.." • "..syncStatusDetail); Print("Database hash: "..BuildDatabaseHash()); Print("Responders: "..CountResponders()); for _,u in ipairs(GetAddonUsers()) do Print("  "..u.name.." - v"..u.version.." / p"..tostring(u.protocol)) end; return end
    if msg=="version" then Print("GuildSharedIgnore v"..VERSION.." / protocol "..PROTOCOL); Print("Highest detected version: v"..GetHighestAddonVersion()); return end
    if GSI.CreateUI then GSI.CreateUI(); local f=GSI.GetFrame and GSI.GetFrame(); if f then if f:IsShown() then f:Hide() else f:Show(); f:Raise(); f:EnableKeyboard(true); f:SetPropagateKeyboardInput(true); if GSI.RefreshList then GSI.RefreshList() end; if GSI.RefreshVersionDisplay then GSI.RefreshVersionDisplay() end; if GSI.RefreshSyncStatus then GSI.RefreshSyncStatus() end end end else Print("|cffff4444GuildSharedIgnore GUI is not loaded.|r") end
end
InitializeDB(); RegisterPrefix(); RegisterAddonUser(LocalName(),VERSION,PROTOCOL); RegisterChatFilters()
