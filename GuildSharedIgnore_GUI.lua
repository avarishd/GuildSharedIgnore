local ADDON_NAME="GuildSharedIgnore"
GSI=GSI or {}
local frame,headerFrame,scrollFrame,scrollChild
local playerBox,noteBox,searchBox,categoryDropDown
local announceCheck,announceText,muteCheck,muteText,deleteConfirmCheck,deleteConfirmText
local undoButton,lastRemovedEntry
local rows,visibleRows={},{}
local noteEditorFrame,noteEditorBox,noteEditorCategory
local noteEditorTarget,editingNoteFor
local settingsButton,settingsPanel,settingsOpacitySlider,settingsOpacityText
local sortColumn="player"
local sortAscending=true
local RefreshList
local AnnounceRemovedPlayer
local RemoveEntry
local versionText,githubCopyFrame,githubClickCatcher,footerGithub
local syncStatusText
local categoryDropDownCounter=0
local openCategoryMenu
local BG={0.018,0.021,0.027,0.98}
local PANEL={0.027,0.032,0.040,1}
local PANEL_ALT={0.14,0.15,0.17,1}
local PANEL2={0.040,0.047,0.058,1}
local BORDER={0.12,0.16,0.21,1}
local ACCENT={0.20,0.58,0.86}
local TEXT={0.84,0.87,0.91}
local MUTED={0.43,0.48,0.55}
local GREEN={0.20,0.85,0.35}
local GOLD={1.00,0.80,0.00}
local RED={1.00,0.20,0.20}
local ORANGE={1.00,0.55,0.15}
local HUNTER_GREEN={0.671,0.831,0.451}
local SKY_BLUE={0.345,0.651,1.00}
local guiAlpha=1
local guiAlphaTextures={}
local CATEGORY_COLORS={
["Toxic"]={0.95,0.28,0.28},
["Bad"]={1.00,0.52,0.18},
["Leaver"]={0.95,0.72,0.22},
["Scammer"]={0.82,0.38,0.88},
["AFK"]={0.58,0.68,0.82},
["Bad Attitude"]={0.92,0.42,0.52},
["Ignore List"]={0.40,0.72,0.82},
["Other"]={0.70,0.74,0.80}
}
local function ClearInputBox(box)
if not box then return end
box:SetText("")
box:ClearFocus()
end
local function ClearInputFields(except)
local boxes={playerBox,noteBox,searchBox}
for _,box in ipairs(boxes) do
if box and box~=except and box:HasFocus() then
box:SetText("")
box:ClearFocus()
end
end
end
local function SetGuiTextureColor(texture,r,g,b,a)
guiAlphaTextures[texture]={r,g,b,a}
texture:SetColorTexture(r,g,b,a*guiAlpha)
end
local function SetGuiAlpha(alpha)
guiAlpha=math.max(0.2,math.min(1,tonumber(alpha) or 1))
GuildSharedIgnoreDB.guiAlpha=guiAlpha
for texture,color in pairs(guiAlphaTextures) do
texture:SetColorTexture(color[1],color[2],color[3],color[4]*guiAlpha)
end
if settingsOpacitySlider then
settingsOpacitySlider:SetValue(guiAlpha)
end
if settingsOpacityText then
settingsOpacityText:SetText(tostring(math.floor(guiAlpha*100+0.5)).."%")
end
end
local function SetBackdropFill(object,color)
SetGuiTextureColor(object.gsiBackdropFill,color[1],color[2],color[3],color[4])
end
local function SetBackdropBorder(object,color)
for _,edge in pairs(object.gsiBackdropBorder) do
edge:SetColorTexture(color[1],color[2],color[3],color[4])
end
end
local function ApplyBackdrop(object,bg,border)
object.gsiBackdropFill=object:CreateTexture(nil,"ARTWORK")
object.gsiBackdropFill:SetPoint("TOPLEFT",object,"TOPLEFT",1,-1)
object.gsiBackdropFill:SetPoint("BOTTOMRIGHT",object,"BOTTOMRIGHT",-1,1)
SetBackdropFill(object,bg)
local top=object:CreateTexture(nil,"ARTWORK")
top:SetPoint("TOPLEFT",object,"TOPLEFT")
top:SetPoint("TOPRIGHT",object,"TOPRIGHT")
top:SetHeight(1)
local bottom=object:CreateTexture(nil,"ARTWORK")
bottom:SetPoint("BOTTOMLEFT",object,"BOTTOMLEFT")
bottom:SetPoint("BOTTOMRIGHT",object,"BOTTOMRIGHT")
bottom:SetHeight(1)
local left=object:CreateTexture(nil,"ARTWORK")
left:SetPoint("TOPLEFT",object,"TOPLEFT")
left:SetPoint("BOTTOMLEFT",object,"BOTTOMLEFT")
left:SetWidth(1)
local right=object:CreateTexture(nil,"ARTWORK")
right:SetPoint("TOPRIGHT",object,"TOPRIGHT")
right:SetPoint("BOTTOMRIGHT",object,"BOTTOMRIGHT")
right:SetWidth(1)
object.gsiBackdropBorder={top=top,bottom=bottom,left=left,right=right}
SetBackdropBorder(object,border)
end
local function SetFontStringColor(fontString,r,g,b,a)
if fontString then
fontString:SetTextColor(r,g,b,a or 1)
end
end
local function SetToggleTooltip(target,owner,title,description)
target:EnableMouse(true)
target:SetScript("OnEnter",function()
GameTooltip:SetOwner(owner,"ANCHOR_TOP")
GameTooltip:SetText(title,1,1,1)
GameTooltip:AddLine(description,0.75,0.78,0.82,true)
GameTooltip:Show()
end)
target:SetScript("OnLeave",function()
GameTooltip:Hide()
end)
end
local function UpdateUndoButtonAppearance(enabled)
if not undoButton then
return
end
local text=undoButton:GetFontString()
if enabled then
SetBackdropFill(undoButton,PANEL2)
SetBackdropBorder(undoButton,BORDER)
SetFontStringColor(text,TEXT[1],TEXT[2],TEXT[3])
else
SetBackdropFill(undoButton,PANEL)
SetBackdropBorder(undoButton,BORDER)
SetFontStringColor(text,MUTED[1],MUTED[2],MUTED[3])
end
end
local function SetUndoButtonEnabled(enabled)
if not undoButton then
return
end
undoButton:SetEnabled(enabled)
UpdateUndoButtonAppearance(enabled)
end
local function MakeButton(parent,width,height,text)
local button=CreateFrame("Button",nil,parent)
button:SetSize(width,height)
ApplyBackdrop(button,PANEL2,BORDER)
button:SetText(text)
button:SetNormalFontObject(GameFontNormalSmall)
button:SetHighlightFontObject(GameFontHighlightSmall)
button:SetScript("OnEnter",function(self)
SetBackdropFill(self,{0.075,0.12,0.17,1})
SetBackdropBorder(self,ACCENT)
end)
button:SetScript("OnLeave",function(self)
SetBackdropFill(self,PANEL2)
SetBackdropBorder(self,BORDER)
end)
return button
end
local function MakeEditBox(parent,width,height,placeholder)
local box=CreateFrame("EditBox",nil,parent)
box:SetSize(width,height)
box:SetAutoFocus(false)
box:SetFontObject(ChatFontNormal)
box:SetTextColor(TEXT[1],TEXT[2],TEXT[3])
box:SetTextInsets(8,8,0,0)
ApplyBackdrop(box,BG,BORDER)
local hint=box:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
hint:SetPoint("LEFT",box,"LEFT",8,0)
hint:SetText(placeholder)
SetFontStringColor(hint,MUTED[1],MUTED[2],MUTED[3])
box.hint=hint
local function UpdateHint()
if box:GetText()=="" and not box:HasFocus() then
hint:Show()
else
hint:Hide()
end
end
box:SetScript("OnTextChanged",UpdateHint)
box:SetScript("OnEditFocusGained",function(self)
hint:Hide()
SetBackdropBorder(self,ACCENT)
end)
box:SetScript("OnEditFocusLost",function(self)
UpdateHint()
SetBackdropBorder(self,BORDER)
end)
box:SetScript("OnEscapePressed",function(self)
if self.clearOnEscape then
self:SetText("")
end
self:ClearFocus()
end)
box:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" and self.clearOnRightClick then
ClearInputBox(self)
end
end)
UpdateHint()
return box
end
local function GetCategoryColor(category)
return unpack(CATEGORY_COLORS[category] or CATEGORY_COLORS["Other"])
end
local function CloseCategoryMenu()
if openCategoryMenu then
openCategoryMenu:Hide()
openCategoryMenu=nil
end
end
local function SetCategoryText(dropDown,category)
category=category or "Other"
dropDown.selectedCategory=category
if dropDown.text then
dropDown.text:SetText(category)
local r,g,b=GetCategoryColor(category)
SetFontStringColor(dropDown.text,r,g,b)
end
if dropDown.arrow then
dropDown.arrow:SetText("+")
SetFontStringColor(dropDown.arrow,MUTED[1],MUTED[2],MUTED[3])
end
end
local function CreateCategoryDropDown(parent,width,height)
categoryDropDownCounter=categoryDropDownCounter+1
local dropDown=CreateFrame("Frame",ADDON_NAME.."CategoryDropDown"..categoryDropDownCounter,parent)
dropDown:SetSize(width,height)
ApplyBackdrop(dropDown,BG,BORDER)
local button=CreateFrame("Button",nil,dropDown)
button:SetAllPoints()
button:SetFrameLevel(dropDown:GetFrameLevel()+2)
local text=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
text:SetPoint("LEFT",button,"LEFT",8,0)
text:SetPoint("RIGHT",button,"RIGHT",-24,0)
text:SetJustifyH("LEFT")
text:SetWordWrap(false)
dropDown.text=text
button.text=text
local arrow=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
arrow:SetPoint("RIGHT",button,"RIGHT",-7,0)
arrow:SetText("▼")
SetFontStringColor(arrow,MUTED[1],MUTED[2],MUTED[3])
dropDown.arrow=arrow
local menu=CreateFrame("Frame",nil,UIParent)
menu:SetFrameStrata("TOOLTIP")
menu:SetFrameLevel(200)
menu:SetWidth(width)
menu:Hide()
menu:EnableMouse(true)
ApplyBackdrop(menu,PANEL2,BORDER)
dropDown.menu=menu
local categories=GSI.GetCategories()
for i,category in ipairs(categories) do
local option=CreateFrame("Button",nil,menu)
option:SetHeight(25)
option:SetPoint("TOPLEFT",menu,"TOPLEFT",1,-1-(i-1)*25)
option:SetPoint("TOPRIGHT",menu,"TOPRIGHT",-1,-1-(i-1)*25)
option.category=category
ApplyBackdrop(option,PANEL2,BORDER)
local optionText=option:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
optionText:SetPoint("LEFT",option,"LEFT",8,0)
optionText:SetPoint("RIGHT",option,"RIGHT",-5,0)
optionText:SetJustifyH("LEFT")
optionText:SetText(category)
local r,g,b=GetCategoryColor(category)
SetFontStringColor(optionText,r,g,b)
option.text=optionText
option:SetScript("OnEnter",function(self)
SetBackdropFill(self,{0.075,0.12,0.17,1})
SetBackdropBorder(self,ACCENT)
end)
option:SetScript("OnLeave",function(self)
SetBackdropFill(self,PANEL2)
SetBackdropBorder(self,BORDER)
end)
option:SetScript("OnClick",function(self)
dropDown.selectedCategory=self.category
SetCategoryText(dropDown,self.category)
CloseCategoryMenu()
end)
end
menu:SetHeight(table.getn(categories)*25+2)
button:SetScript("OnEnter",function()
SetBackdropBorder(dropDown,ACCENT)
end)
button:SetScript("OnLeave",function()
if not menu:IsShown() then
SetBackdropBorder(dropDown,BORDER)
end
end)
button:SetScript("OnClick",function()
if menu:IsShown() then
CloseCategoryMenu()
return
end
CloseCategoryMenu()
menu:ClearAllPoints()
menu:SetPoint("TOPLEFT",dropDown,"BOTTOMLEFT",0,-2)
menu:Show()
openCategoryMenu=menu
SetBackdropBorder(dropDown,ACCENT)
end)
dropDown.selectedCategory="Other"
SetCategoryText(dropDown,"Other")
return dropDown
end
local function CloseNoteEditor()
editingNoteFor=nil
CloseCategoryMenu()
if noteEditorFrame then
noteEditorFrame:Hide()
end
if frame then
frame:EnableKeyboard(true)
end
end
local function CloseUIOnEscape()
if noteEditorFrame and noteEditorFrame:IsShown() then
noteEditorFrame:SetPropagateKeyboardInput(false)
CloseNoteEditor()
end
CloseCategoryMenu()
if githubCopyFrame then
githubCopyFrame:Hide()
end
if settingsPanel then
settingsPanel:Hide()
end
if frame then
frame:SetPropagateKeyboardInput(false)
frame:Hide()
end
end
local function SaveNoteEditor()
if not editingNoteFor then
CloseNoteEditor()
return
end
local category="Other"
if noteEditorCategory then
category=noteEditorCategory.selectedCategory or "Other"
end
GSI.UpdateNote(editingNoteFor,noteEditorBox:GetText() or "",category)
CloseNoteEditor()
end
local function CreateNoteEditor()
if noteEditorFrame then
return
end
noteEditorFrame=CreateFrame("Frame","GuildSharedIgnoreNoteEditor",UIParent)
noteEditorFrame:SetSize(450,205)
noteEditorFrame:SetPoint("CENTER")
noteEditorFrame:SetFrameStrata("TOOLTIP")
noteEditorFrame:SetMovable(true)
noteEditorFrame:EnableMouse(true)
noteEditorFrame:EnableKeyboard(true)
noteEditorFrame:SetPropagateKeyboardInput(true)
noteEditorFrame:RegisterForDrag("LeftButton")
ApplyBackdrop(noteEditorFrame,BG,BORDER)
local bar=noteEditorFrame:CreateTexture(nil,"ARTWORK")
SetGuiTextureColor(bar,PANEL2[1],PANEL2[2],PANEL2[3],1)
bar:SetPoint("TOPLEFT",1,-1)
bar:SetPoint("TOPRIGHT",-1,-1)
bar:SetHeight(34)
local title=noteEditorFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("LEFT",bar,"LEFT",12,0)
title:SetText("EDIT REPORT")
SetFontStringColor(title,ACCENT[1],ACCENT[2],ACCENT[3])
noteEditorTarget=noteEditorFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
noteEditorTarget:SetPoint("TOPLEFT",noteEditorFrame,"TOPLEFT",12,-44)
noteEditorBox=MakeEditBox(noteEditorFrame,426,30,"Enter note...")
noteEditorBox:SetPoint("TOPLEFT",noteEditorFrame,"TOPLEFT",12,-64)
noteEditorBox:SetMaxLetters(255)
noteEditorCategory=CreateCategoryDropDown(noteEditorFrame,160,30)
noteEditorCategory:SetPoint("TOPLEFT",noteEditorFrame,"TOPLEFT",8,-102)
local categoryLabel=noteEditorFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
categoryLabel:SetPoint("LEFT",noteEditorCategory,"RIGHT",8,0)
categoryLabel:SetText("Category")
SetFontStringColor(categoryLabel,MUTED[1],MUTED[2],MUTED[3])
local cancel=MakeButton(noteEditorFrame,75,25,"CANCEL")
cancel:SetPoint("BOTTOMRIGHT",noteEditorFrame,"BOTTOMRIGHT",-12,10)
cancel:SetScript("OnClick",CloseNoteEditor)
local save=MakeButton(noteEditorFrame,75,25,"SAVE")
save:SetPoint("RIGHT",cancel,"LEFT",-6,0)
save:SetScript("OnClick",SaveNoteEditor)
noteEditorFrame:SetScript("OnDragStart",function(self)
self:StartMoving()
end)
noteEditorFrame:SetScript("OnDragStop",function(self)
self:StopMovingOrSizing()
end)
noteEditorFrame:SetScript("OnKeyDown",function(self,key)
if key=="ESCAPE" then
CloseUIOnEscape()
end
end)
noteEditorBox:SetScript("OnEnterPressed",SaveNoteEditor)
noteEditorBox:SetScript("OnEscapePressed",CloseUIOnEscape)
noteEditorFrame:Hide()
end
local function OpenNoteEditor(name)
name=GSI.Normalize(name)
local entry=GSI.GetEntry(name)
if not entry then
return
end
CreateNoteEditor()
editingNoteFor=name
noteEditorTarget:SetText("Player: "..name)
noteEditorBox:SetText(entry.note or "")
noteEditorBox:SetCursorPosition(0)
noteEditorCategory.selectedCategory=entry.category or "Other"
SetCategoryText(noteEditorCategory,noteEditorCategory.selectedCategory)
if frame then
frame:EnableKeyboard(false)
end
noteEditorFrame:Show()
noteEditorFrame:Raise()
noteEditorFrame:SetPropagateKeyboardInput(true)
noteEditorBox:SetFocus()
end
local function CreateRow(index)
local row=CreateFrame("Frame",nil,scrollChild)
row:SetHeight(23)
ApplyBackdrop(row,PANEL,{0.055,0.065,0.080,1})
row.player=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.player:SetJustifyH("LEFT")
row.player:SetWordWrap(false)
row.addedBy=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.addedBy:SetJustifyH("LEFT")
row.addedBy:SetWordWrap(false)
row.category=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.category:SetJustifyH("LEFT")
row.category:SetWordWrap(false)
row.note=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.note:SetJustifyH("LEFT")
row.note:SetWordWrap(false)
row.date=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
row.date:SetJustifyH("CENTER")
row.noteButton=CreateFrame("Button",nil,row)
row.noteButton:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
row.noteButton:SetScript("OnEnter",function()
SetBackdropFill(row,{0.20,0.22,0.25,1})
end)
row.noteButton:SetScript("OnLeave",function()
if row.alt then
SetBackdropFill(row,PANEL_ALT)
else
SetBackdropFill(row,PANEL)
end
end)
row.noteButton:SetScript("OnClick",function()
if row.entryName then
OpenNoteEditor(row.entryName)
end
end)
row.remove=CreateFrame("Button",nil,row)
row.remove:SetText("×")
row.remove:SetNormalFontObject(GameFontNormal)
row.remove:SetHighlightFontObject(GameFontHighlight)
SetFontStringColor(row.remove:GetFontString(),0.55,0.59,0.65)
row.remove:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
row.remove:SetScript("OnEnter",function(self)
SetFontStringColor(self:GetFontString(),1,0.25,0.25)
end)
row.remove:SetScript("OnLeave",function(self)
SetFontStringColor(self:GetFontString(),0.55,0.59,0.65)
end)
row.remove:SetScript("OnClick",function()
if row.entryName then
local name=row.entryName
local entry=GSI.GetEntry and GSI.GetEntry(name)
if entry then
if GuildSharedIgnoreDB.confirmDelete then
StaticPopup_Show("GSI_CONFIRM_REMOVE",name,nil,{name=name})
else
RemoveEntry(name)
end
end
end
end)
rows[index]=row
return row
end
local function GetSortHeaderText(label,column)
if sortColumn~=column then
return label
end
if sortAscending then
return "> "..label.." <"
end
return "< "..label.." >"
end
local function UpdateSortHeaders()
if not frame then
return
end
frame.hPlayer:SetText(GetSortHeaderText("PLAYER","player"))
frame.hAdded:SetText(GetSortHeaderText("ADDED BY","addedBy"))
frame.hCategory:SetText(GetSortHeaderText("CATEGORY","category"))
frame.hDate:SetText(GetSortHeaderText("DATE","date"))
frame.hNote:SetText("NOTE")
end
local function SetSortColumn(column)
if sortColumn==column then
sortAscending=not sortAscending
else
sortColumn=column
sortAscending=true
end
if GSI.SetSortState then
GSI.SetSortState(sortColumn,sortAscending)
end
UpdateSortHeaders()
RefreshList()
end
local function MakeHeaderButton(parent,fontString,column)
local button=CreateFrame("Button",nil,parent)
button:SetFrameLevel(parent:GetFrameLevel()+5)
button:SetScript("OnMouseDown",function(self,mouseButton)
if mouseButton=="RightButton" then
ClearInputFields()
end
end)
button:SetScript("OnClick",function()
SetSortColumn(column)
end)
button:SetScript("OnEnter",function()
SetFontStringColor(fontString,ACCENT[1],ACCENT[2],ACCENT[3])
end)
button:SetScript("OnLeave",function()
SetFontStringColor(fontString,MUTED[1],MUTED[2],MUTED[3])
end)
return button
end
local function UpdateColumns()
if not scrollFrame or not scrollChild or not frame then
return
end
local width=scrollFrame:GetWidth()
if not width or width<100 then
return
end
width=width-4
scrollChild:SetWidth(width)
local playerWidth=math.floor(width*0.17)
local addedWidth=math.floor(width*0.13)
local categoryWidth=math.floor(width*0.13)
local dateWidth=math.floor(width*0.11)
local removeWidth=30
local noteWidth=width-playerWidth-addedWidth-categoryWidth-dateWidth-removeWidth
if noteWidth<100 then
noteWidth=100
end
frame.hPlayer:SetWidth(playerWidth)
frame.hAdded:SetWidth(addedWidth)
frame.hCategory:SetWidth(categoryWidth)
frame.hNote:SetWidth(noteWidth)
frame.hDate:SetWidth(dateWidth)
frame.hPlayer:ClearAllPoints()
frame.hPlayer:SetPoint("LEFT",frame.tableHeader,"LEFT",8,0)
frame.hAdded:ClearAllPoints()
frame.hAdded:SetPoint("LEFT",frame.hPlayer,"RIGHT",0,0)
frame.hCategory:ClearAllPoints()
frame.hCategory:SetPoint("LEFT",frame.hAdded,"RIGHT",0,0)
frame.hNote:ClearAllPoints()
frame.hNote:SetPoint("LEFT",frame.hCategory,"RIGHT",0,0)
frame.hDate:ClearAllPoints()
frame.hDate:SetPoint("LEFT",frame.hNote,"RIGHT",0,0)
if frame.sortPlayer then
frame.sortPlayer:ClearAllPoints()
frame.sortPlayer:SetPoint("TOPLEFT",frame.hPlayer,"TOPLEFT",-8,0)
frame.sortPlayer:SetSize(playerWidth,25)
end
if frame.sortAdded then
frame.sortAdded:ClearAllPoints()
frame.sortAdded:SetPoint("TOPLEFT",frame.hAdded,"TOPLEFT",0,0)
frame.sortAdded:SetSize(addedWidth,25)
end
if frame.sortCategory then
frame.sortCategory:ClearAllPoints()
frame.sortCategory:SetPoint("TOPLEFT",frame.hCategory,"TOPLEFT",0,0)
frame.sortCategory:SetSize(categoryWidth,25)
end
if frame.sortDate then
frame.sortDate:ClearAllPoints()
frame.sortDate:SetPoint("TOPLEFT",frame.hDate,"TOPLEFT",0,0)
frame.sortDate:SetSize(dateWidth,25)
end
for _,row in ipairs(rows) do
row.player:SetWidth(playerWidth-12)
row.addedBy:SetWidth(addedWidth-8)
row.category:SetWidth(categoryWidth-8)
row.note:SetWidth(noteWidth-8)
row.date:SetWidth(dateWidth)
row.player:ClearAllPoints()
row.player:SetPoint("LEFT",row,"LEFT",8,0)
row.addedBy:ClearAllPoints()
row.addedBy:SetPoint("LEFT",row,"LEFT",playerWidth+4,0)
row.category:ClearAllPoints()
row.category:SetPoint("LEFT",row,"LEFT",playerWidth+addedWidth+4,0)
row.note:ClearAllPoints()
row.note:SetPoint("LEFT",row,"LEFT",playerWidth+addedWidth+categoryWidth+4,0)
row.date:ClearAllPoints()
row.date:SetPoint("LEFT",row,"LEFT",playerWidth+addedWidth+categoryWidth+noteWidth,0)
row.remove:ClearAllPoints()
row.remove:SetPoint("RIGHT",row,"RIGHT",-2,0)
row.remove:SetSize(removeWidth,23)
row.noteButton:ClearAllPoints()
row.noteButton:SetPoint("LEFT",row,"LEFT",playerWidth+addedWidth+categoryWidth,0)
row.noteButton:SetSize(noteWidth,23)
end
end
local function SortEntries(entries)
table.sort(entries,function(a,b)
if not a and not b then
return false
end
if not a then
return false
end
if not b then
return true
end
local result=0
if sortColumn=="player" then
local av=string.lower(a.name or "")
local bv=string.lower(b.name or "")
if av<bv then result=-1 elseif av>bv then
result=1
end
elseif sortColumn=="addedBy" then
local av=string.lower(a.addedBy or "")
local bv=string.lower(b.addedBy or "")
if av<bv then result=-1 elseif av>bv then
result=1
end
elseif sortColumn=="category" then
local av=string.lower(a.category or "Other")
local bv=string.lower(b.category or "Other")
if av<bv then result=-1 elseif av>bv then
result=1
end
elseif sortColumn=="date" then
local av=tonumber(a.time) or 0
local bv=tonumber(b.time) or 0
if av<bv then result=-1 elseif av>bv then
result=1
end
end
if result==0 then
local av=string.lower(a.name or "")
local bv=string.lower(b.name or "")
if av<bv then result=-1 elseif av>bv then
result=1
end
end
if sortAscending then
return result<0
end
return result>0
end)
end
local function HideVersionTooltip()
if GameTooltip then
GameTooltip:Hide()
end
end
local function ShowVersionTooltip()
if not versionText or not versionText:IsShown() then
return
end
if not GSI.GetAddonUsers then
return
end
local users=GSI.GetAddonUsers() or {}
local highestVersion=GSI.GetHighestAddonVersion and GSI.GetHighestAddonVersion() or GSI.GetVersion()
GameTooltip:SetOwner(versionText.hitbox or versionText,"ANCHOR_BOTTOMLEFT")
GameTooltip:ClearLines()
GameTooltip:AddLine("GuildSharedIgnore Users",1,0.82,0)
GameTooltip:AddLine(" ")
if table.getn(users)<=0 then
GameTooltip:AddLine("No other addon users detected.",0.65,0.65,0.65)
else
for _,user in ipairs(users) do
local playerR,playerG,playerB=GSI.GetClassColor(user.name)
local version=tostring(user.version or "0")
local versionR,versionG,versionB=RED[1],RED[2],RED[3]
if GSI.CompareVersions and GSI.CompareVersions(version,highestVersion)>=0 then
versionR=GREEN[1]
versionG=GREEN[2]
versionB=GREEN[3]
end
GameTooltip:AddDoubleLine(user.name,"v"..version,playerR,playerG,playerB,versionR,versionG,versionB)
if user.protocol and GSI.GetProtocol and user.protocol~=GSI.GetProtocol() then
GameTooltip:AddLine("Protocol mismatch: peer "..tostring(user.protocol)..", local "..tostring(GSI.GetProtocol()),RED[1],RED[2],RED[3])
end
end
end
GameTooltip:AddLine(" ")
GameTooltip:AddDoubleLine("Highest version","v"..tostring(highestVersion),0.65,0.65,0.65,GREEN[1],GREEN[2],GREEN[3])
GameTooltip:AddDoubleLine("Protocol","v"..tostring(GSI.GetProtocol and GSI.GetProtocol() or "?"),0.65,0.65,0.65,GREEN[1],GREEN[2],GREEN[3])
local currentVersion=GSI.GetVersion()
if GSI.CompareVersions and GSI.CompareVersions(currentVersion,highestVersion)<0 then
GameTooltip:AddLine("Your addon is outdated.",RED[1],RED[2],RED[3])
else
GameTooltip:AddLine("Your addon is up to date.",GREEN[1],GREEN[2],GREEN[3])
end
GameTooltip:Show()
end
local function RefreshVersionTooltip()
if GameTooltip:IsShown() and versionText and versionText.hitbox and GameTooltip:GetOwner()==versionText.hitbox then
ShowVersionTooltip()
end
end
local function UpdateVersionDisplay()
if not versionText then
return
end
local currentVersion=GSI.GetVersion()
local highestVersion=GSI.GetHighestAddonVersion()
versionText:SetText("v"..currentVersion)
if GSI.CompareVersions and GSI.CompareVersions(currentVersion,highestVersion)<0 then
SetFontStringColor(versionText,RED[1],RED[2],RED[3])
else
SetFontStringColor(versionText,GREEN[1],GREEN[2],GREEN[3])
end
RefreshVersionTooltip()
end
local function ShowGitHubCopyBox()
if not footerGithub then
return
end
if not githubClickCatcher then
githubClickCatcher=CreateFrame("Button",nil,UIParent)
githubClickCatcher:SetAllPoints(UIParent)
githubClickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
githubClickCatcher:SetFrameLevel(150)
githubClickCatcher:EnableMouse(true)
githubClickCatcher:Hide()
githubClickCatcher:SetScript("OnMouseDown",function()
if githubCopyFrame and githubCopyFrame:IsShown() then
    githubCopyFrame:Hide()
    githubClickCatcher:Hide()
    if githubCopyFrame.editBox then
        githubCopyFrame.editBox:ClearFocus()
    end
end
end)
end
if not githubCopyFrame then
githubCopyFrame=CreateFrame("Frame",nil,UIParent)
githubCopyFrame:SetSize(390,72)
githubCopyFrame:SetFrameStrata("TOOLTIP")
githubCopyFrame:SetFrameLevel(200)
githubCopyFrame:EnableMouse(true)
githubCopyFrame:SetClampedToScreen(true)
ApplyBackdrop(githubCopyFrame,PANEL2,BORDER)
local label=githubCopyFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
label:SetPoint("TOPLEFT",githubCopyFrame,"TOPLEFT",10,-8)
label:SetText("GitHub URL - Ctrl+C to copy:")
SetFontStringColor(label,MUTED[1],MUTED[2],MUTED[3])
local box=CreateFrame("EditBox",nil,githubCopyFrame)
box:SetSize(370,28)
box:SetPoint("BOTTOM",githubCopyFrame,"BOTTOM",0,8)
box:SetAutoFocus(false)
box:SetFontObject(ChatFontNormal)
box:SetTextColor(TEXT[1],TEXT[2],TEXT[3])
box:SetTextInsets(7,7,0,0)
ApplyBackdrop(box,BG,BORDER)
box:SetText("https://github.com/avarishd/GuildSharedIgnore")
githubCopyFrame.editBox=box
box:SetScript("OnEscapePressed",function()
githubCopyFrame:Hide()
githubClickCatcher:Hide()
box:ClearFocus()
end)
box:SetScript("OnEnterPressed",function()
box:HighlightText()
end)
box:SetScript("OnEditFocusLost",function()
if githubCopyFrame and githubCopyFrame:IsShown() then
    githubCopyFrame:Hide()
    githubClickCatcher:Hide()
end
end)
githubCopyFrame:SetScript("OnMouseDown",function()
box:SetFocus()
box:HighlightText()
end)
end
githubCopyFrame:ClearAllPoints()
githubCopyFrame:SetPoint("BOTTOMLEFT",footerGithub,"TOPLEFT",-8,5)
githubCopyFrame:Show()
githubCopyFrame:Raise()
githubClickCatcher:Show()
githubClickCatcher:SetFrameLevel(githubCopyFrame:GetFrameLevel()-1)
githubCopyFrame.editBox:SetFocus()
githubCopyFrame.editBox:HighlightText()
end
local function UpdateSyncBorder(status)
if not frame then
return
end
if status=="Complete" then
SetBackdropBorder(frame,GREEN)
elseif status=="Failed" then
SetBackdropBorder(frame,RED)
elseif status=="Syncing" then
SetBackdropBorder(frame,ACCENT)
else
SetBackdropBorder(frame,BORDER)
end
end
local function UpdateSyncStatus()
if not syncStatusText or not GSI.GetSyncStatus then
return
end
local status,detail,active,lastComplete,nextAuto,incremental,imported,updated,deleted=GSI.GetSyncStatus()
local text="SYNC: "
if status=="Syncing" then
text=text.."SYNCING"
if detail and detail~="" then
text=text.." • "..detail
end
SetFontStringColor(syncStatusText,ACCENT[1],ACCENT[2],ACCENT[3])
elseif status=="Complete" then
text=text.."OK"
if detail and detail~="" then
text=text.." • "..detail
end
SetFontStringColor(syncStatusText,GREEN[1],GREEN[2],GREEN[3])
elseif status=="Failed" then
text=text.."FAILED"
if detail and detail~="" then
text=text.." • "..detail
end
SetFontStringColor(syncStatusText,RED[1],RED[2],RED[3])
else
text=text.."READY"
SetFontStringColor(syncStatusText,MUTED[1],MUTED[2],MUTED[3])
end
if not active and nextAuto and nextAuto>0 and status~="Syncing" then
local remaining=math.max(0,nextAuto-time())
if remaining>0 then
local minutes=math.floor(remaining/60)
local seconds=math.floor(remaining%60)
text=text.." • next "..string.format("%02d:%02d",minutes,seconds)
end
end
syncStatusText:SetText(text)
UpdateSyncBorder(status)
end
GSI.RefreshSyncStatus=UpdateSyncStatus
RefreshList=function()
if not scrollChild then
return
end
local query=""
if searchBox then
query=string.lower(searchBox:GetText() or "")
end
local entries={}
for _,entry in pairs(GuildSharedIgnoreDB.players) do
if entry then
table.insert(entries,entry)
end
end
SortEntries(entries)
visibleRows={}
for _,entry in ipairs(entries) do
local name=string.lower(entry.name or "")
local addedBy=string.lower(entry.addedBy or "")
local note=string.lower(entry.note or "")
local category=string.lower(entry.category or "other")
if query=="" or string.find(name,query,1,true) or string.find(addedBy,query,1,true) or string.find(note,query,1,true) or string.find(category,query,1,true) then
table.insert(visibleRows,entry)
end
end
for _,row in ipairs(rows) do
row:Hide()
end
for i,entry in ipairs(visibleRows) do
local row=rows[i] or CreateRow(i)
row.entryName=entry.name
row.alt=i%2==0
row:ClearAllPoints()
row:SetPoint("TOPLEFT",scrollChild,"TOPLEFT",0,-(i-1)*23)
row:SetWidth(scrollChild:GetWidth())
if row.alt then
SetBackdropFill(row,PANEL_ALT)
else
SetBackdropFill(row,PANEL)
end
row.player:SetText(entry.name or "")
SetFontStringColor(row.player,TEXT[1],TEXT[2],TEXT[3])
local addedBy=entry.addedBy
if not addedBy or addedBy=="" then
addedBy="Unknown"
end
row.addedBy:SetText(addedBy)
local addedByR,addedByG,addedByB=1,1,1
if GSI.GetClassColor then
addedByR,addedByG,addedByB=GSI.GetClassColor(addedBy)
end
SetFontStringColor(row.addedBy,addedByR,addedByG,addedByB)
local category=entry.category or "Other"
row.category:SetText(category)
local categoryR,categoryG,categoryB=GetCategoryColor(category)
SetFontStringColor(row.category,categoryR,categoryG,categoryB)
if entry.note and entry.note~="" then
row.note:SetText(entry.note)
SetFontStringColor(row.note,0.78,0.81,0.86)
else
row.note:SetText("—")
SetFontStringColor(row.note,0.32,0.36,0.42)
end
row.date:SetText(GSI.FormatDate(entry.time))
SetFontStringColor(row.date,0.45,0.50,0.57)
row:Show()
end
scrollChild:SetHeight(math.max(1,table.getn(visibleRows)*23))
local myCount=0
local myName=GSI.Key(GSI.GetPlayerName())
for _,entry in ipairs(entries) do
if entry.addedBy and GSI.Key(entry.addedBy)==myName then
myCount=myCount+1
end
end
if frame and frame.count then
frame.count:SetText("YOU: "..tostring(myCount).." TOTAL: "..tostring(table.getn(entries)))
end
UpdateColumns()
UpdateVersionDisplay()
UpdateSyncStatus()
end
GSI.RefreshList=RefreshList
GSI.ClearAddFields=function()
if playerBox then
playerBox:SetText("")
end
if noteBox then
noteBox:SetText("")
end
if categoryDropDown then
categoryDropDown.selectedCategory="Other"
SetCategoryText(categoryDropDown,"Other")
end
end
local function AnnounceAddedPlayer(name,note,category,action)
if not GuildSharedIgnoreDB or not GuildSharedIgnoreDB.announceGuild then
return
end
if not IsInGuild or not IsInGuild() then
return
end
if not SendChatMessage then
return
end
local playerName=UnitName("player") or "Unknown"
local text="[GSI] "..tostring(name).." "..(action=="updated" and "updated by " or "added by ")..tostring(playerName)
if category and category~="" and category~="Other" then
text=text.." ["..tostring(category).."]"
end
if note and note~="" then
text=text..": "..tostring(note)
end
pcall(SendChatMessage,text,"GUILD")
end
AnnounceRemovedPlayer=function(name,note,category)
if not GuildSharedIgnoreDB or not GuildSharedIgnoreDB.announceGuild then
return
end
if not IsInGuild or not IsInGuild() then
return
end
if not SendChatMessage then
return
end
local playerName=UnitName("player") or "Unknown"
local text="[GSI] "..tostring(name).." removed by "..tostring(playerName)
if category and category~="" and category~="Other" then
text=text.." ["..tostring(category).."]"
end
if note and note~="" then
text=text..": "..tostring(note)
end
pcall(SendChatMessage,text,"GUILD")
end
local function AddFromFields(nameOverride)
local typedName=nameOverride
if not typedName or typedName=="" then
typedName=playerBox:GetText() or ""
end
typedName=typedName:gsub("^%s+","")
typedName=typedName:gsub("%s+$","")
if typedName=="" then
if UnitExists("target") and UnitIsPlayer("target") then
typedName=UnitName("target") or ""
end
end
typedName=typedName:gsub("^%s+","")
typedName=typedName:gsub("%s+$","")
if typedName=="" then
return false
end
local category=categoryDropDown.selectedCategory or "Other"
local note=noteBox:GetText() or ""
local result,action=GSI.AddPlayer(typedName,note,nil,category)
local success=result and true or false
if success then
AnnounceAddedPlayer(typedName,note,category,action)
playerBox:SetText("")
noteBox:SetText("")
playerBox:ClearFocus()
noteBox:ClearFocus()
categoryDropDown.selectedCategory="Other"
SetCategoryText(categoryDropDown,"Other")
if RefreshList then
RefreshList()
end
end
return success
end
RemoveEntry=function(name)
local entry=GSI.GetEntry and GSI.GetEntry(name)
if entry and GSI.RemovePlayer(name) then
lastRemovedEntry={
name=entry.name,
addedBy=entry.addedBy,
note=entry.note,
category=entry.category
}
SetUndoButtonEnabled(true)
AnnounceRemovedPlayer(name,entry.note,entry.category)
RefreshList()
end
end
StaticPopupDialogs["GSI_CONFIRM_REMOVE"]={
text="Remove %s from the GuildSharedIgnore list?",
button1=YES,
button2=NO,
OnAccept=function(self,data)
if data and data.name then
RemoveEntry(data.name)
end
end,
timeout=0,
whileDead=true,
hideOnEscape=true,
preferredIndex=3
}
local function CreateUI()
if frame then
return
end
SetGuiAlpha(GuildSharedIgnoreDB.guiAlpha or 1)
frame=CreateFrame("Frame","GuildSharedIgnoreFrame",UIParent)
frame:SetSize(850,470)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(50)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:EnableKeyboard(true)
frame:SetPropagateKeyboardInput(true)
frame:SetMovable(true)
ApplyBackdrop(frame,BG,BORDER)
frame:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
frame:SetScript("OnKeyDown",function(self,key)
if key=="ESCAPE" then
CloseUIOnEscape()
end
end)
headerFrame=CreateFrame("Frame",nil,frame)
headerFrame:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
headerFrame:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1)
headerFrame:SetHeight(45)
headerFrame:EnableMouse(true)
headerFrame:SetFrameLevel(51)
local headerBG=headerFrame:CreateTexture(nil,"BACKGROUND")
SetGuiTextureColor(headerBG,0.035,0.045,0.058,1)
headerBG:SetAllPoints()
local logo=headerFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
logo:SetPoint("TOPLEFT",headerFrame,"TOPLEFT",13,-7)
logo:SetText("GSI")
SetFontStringColor(logo,ACCENT[1],ACCENT[2],ACCENT[3])
local title=headerFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("LEFT",logo,"RIGHT",10,0)
title:SetText("Guild Shared Ignore")
SetFontStringColor(title,TEXT[1],TEXT[2],TEXT[3])
versionText=headerFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
versionText:SetPoint("LEFT",title,"RIGHT",8,0)
versionText:SetText("v"..GSI.GetVersion())
UpdateVersionDisplay()
local versionHitbox=CreateFrame("Button",nil,headerFrame)
versionHitbox:SetPoint("LEFT",versionText,"LEFT",-3,0)
versionHitbox:SetPoint("RIGHT",versionText,"RIGHT",3,0)
versionHitbox:SetHeight(20)
versionHitbox:SetFrameLevel(headerFrame:GetFrameLevel()+5)
versionHitbox:SetScript("OnEnter",function()
ShowVersionTooltip()
end)
versionHitbox:SetScript("OnLeave",function()
HideVersionTooltip()
end)
versionText.hitbox=versionHitbox
syncStatusText=headerFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
syncStatusText:SetPoint("TOPLEFT",logo,"BOTTOMLEFT",0,-2)
syncStatusText:SetJustifyH("LEFT")
syncStatusText:SetText("SYNC: READY")
SetFontStringColor(syncStatusText,MUTED[1],MUTED[2],MUTED[3])
local close=CreateFrame("Button",nil,frame)
close:SetSize(36,36)
close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-4,-4)
close:SetFrameLevel(100)
close:EnableMouse(true)
close:SetText("X")
close:SetNormalFontObject(GameFontNormal)
close:SetHighlightFontObject(GameFontHighlight)
local closeText=close:GetFontString()
if closeText then
closeText:SetTextColor(0.65,0.68,0.74)
end
close:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
close:SetScript("OnEnter",function(self)
local text=self:GetFontString()
if text then
text:SetTextColor(1,0.20,0.20)
end
end)
close:SetScript("OnLeave",function(self)
local text=self:GetFontString()
if text then
text:SetTextColor(0.65,0.68,0.74)
end
end)
close:SetScript("OnClick",function()
if settingsPanel then
settingsPanel:Hide()
end
frame:Hide()
end)
settingsButton=CreateFrame("Button",nil,frame)
settingsButton:SetSize(36,36)
settingsButton:SetPoint("RIGHT",close,"LEFT",2,0)
settingsButton:SetFrameLevel(close:GetFrameLevel())
settingsButton:EnableMouse(true)
settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
local settingsIcon=settingsButton:GetNormalTexture()
settingsIcon:SetSize(18,18)
settingsIcon:ClearAllPoints()
settingsIcon:SetPoint("CENTER")
settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton","ADD")
local settingsHighlight=settingsButton:GetHighlightTexture()
settingsHighlight:SetSize(18,18)
settingsHighlight:ClearAllPoints()
settingsHighlight:SetPoint("CENTER")
settingsPanel=CreateFrame("Frame",nil,frame)
settingsPanel:SetSize(250,210)
settingsPanel:SetFrameStrata("DIALOG")
settingsPanel:SetFrameLevel(frame:GetFrameLevel()+100)
settingsPanel:EnableMouse(true)
settingsPanel:SetScript("OnMouseDown",function() end)
settingsPanel:SetScript("OnMouseUp",function() end)
ApplyBackdrop(settingsPanel,PANEL,BORDER)
settingsPanel:SetPoint("TOPRIGHT",settingsButton,"BOTTOMRIGHT",0,-4)
local settingsHeader=settingsPanel:CreateTexture(nil,"BACKGROUND")
settingsHeader:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",1,-1)
settingsHeader:SetPoint("TOPRIGHT",settingsPanel,"TOPRIGHT",-1,-1)
settingsHeader:SetHeight(30)
settingsHeader:SetColorTexture(0.035,0.045,0.058,1)
local settingsTitle=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
settingsTitle:SetPoint("LEFT",settingsPanel,"TOPLEFT",11,-15)
settingsTitle:SetText("SETTINGS")
SetFontStringColor(settingsTitle,ACCENT[1],ACCENT[2],ACCENT[3])
local opacityTitle=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
opacityTitle:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",12,-40)
opacityTitle:SetText("Background opacity")
SetFontStringColor(opacityTitle,TEXT[1],TEXT[2],TEXT[3])
settingsOpacityText=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
settingsOpacityText:SetPoint("TOPRIGHT",settingsPanel,"TOPRIGHT",-12,-40)
SetFontStringColor(settingsOpacityText,ACCENT[1],ACCENT[2],ACCENT[3])
settingsOpacitySlider=CreateFrame("Slider","GuildSharedIgnoreOpacitySlider",settingsPanel,"OptionsSliderTemplate")
settingsOpacitySlider:SetOrientation("HORIZONTAL")
settingsOpacitySlider:SetMinMaxValues(0.2,1)
settingsOpacitySlider:SetValueStep(0.05)
settingsOpacitySlider:SetObeyStepOnDrag(true)
settingsOpacitySlider:SetWidth(220)
settingsOpacitySlider:SetHeight(16)
settingsOpacitySlider:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",15,-59)
local opacityLow=_G[settingsOpacitySlider:GetName().."Low"]
local opacityHigh=_G[settingsOpacitySlider:GetName().."High"]
opacityLow:SetText("20%")
opacityHigh:SetText("100%")
opacityLow:SetTextColor(MUTED[1],MUTED[2],MUTED[3])
opacityHigh:SetTextColor(MUTED[1],MUTED[2],MUTED[3])
_G[settingsOpacitySlider:GetName().."Text"]:SetText("")
local settingsDivider=settingsPanel:CreateTexture(nil,"ARTWORK")
settingsDivider:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",10,-91)
settingsDivider:SetPoint("TOPRIGHT",settingsPanel,"TOPRIGHT",-10,-91)
settingsDivider:SetHeight(1)
settingsDivider:SetColorTexture(BORDER[1],BORDER[2],BORDER[3],1)
settingsOpacitySlider:SetScript("OnValueChanged",function(self,value)
SetGuiAlpha(value)
end)
SetGuiAlpha(guiAlpha)
settingsPanel:Hide()
settingsButton:SetScript("OnClick",function()
if settingsPanel:IsShown() then
settingsPanel:Hide()
else
settingsOpacitySlider:SetValue(guiAlpha)
settingsPanel:Show()
settingsPanel:Raise()
end
end)
settingsButton:SetScript("OnEnter",function(self)
settingsIcon:SetVertexColor(0.60,0.85,1)
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:SetText("Settings",1,1,1)
GameTooltip:AddLine("Adjust GUI opacity, guild announcements, and addon messages.",0.75,0.78,0.82,true)
GameTooltip:Show()
end)
settingsButton:SetScript("OnLeave",function()
settingsIcon:SetVertexColor(1,1,1)
GameTooltip:Hide()
end)
headerFrame:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
elseif button=="LeftButton" then
frame:StartMoving()
end
end)
headerFrame:SetScript("OnMouseUp",function(self,button)
if button=="LeftButton" then
frame:StopMovingOrSizing()
end
end)
playerBox=MakeEditBox(frame,110,28,"Player...")
playerBox.clearOnEscape=true
playerBox.clearOnRightClick=true
playerBox:SetPoint("TOPLEFT",frame,"TOPLEFT",10,-49)
categoryDropDown=CreateCategoryDropDown(frame,105,28)
categoryDropDown:SetPoint("LEFT",playerBox,"RIGHT",6,0)
noteBox=MakeEditBox(frame,160,28,"Note...")
noteBox.clearOnEscape=true
noteBox.clearOnRightClick=true
noteBox:SetMaxLetters(255)
noteBox:SetPoint("LEFT",categoryDropDown,"RIGHT",6,0)
local add=MakeButton(frame,52,28,"ADD")
add:SetPoint("LEFT",noteBox,"RIGHT",6,0)
add:SetScript("OnClick",function()
AddFromFields()
end)
playerBox:SetScript("OnEnterPressed",function()
AddFromFields()
end)
noteBox:SetScript("OnEnterPressed",function()
AddFromFields()
end)
searchBox=MakeEditBox(frame,175,28,"Search players / notes...")
searchBox.clearOnEscape=true
searchBox.clearOnRightClick=true
searchBox:SetPoint("LEFT",add,"RIGHT",6,0)
searchBox:SetScript("OnTextChanged",function(self)
if self:GetText()=="" and not self:HasFocus() then
self.hint:Show()
else
self.hint:Hide()
end
RefreshList()
end)
searchBox:SetScript("OnEnterPressed",function(self)
self:ClearFocus()
end)
local sync=MakeButton(frame,52,28,"SYNC")
sync:SetPoint("LEFT",searchBox,"RIGHT",6,0)
sync:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
sync:SetScript("OnClick",function()
GSI.RequestSync()
end)
undoButton=MakeButton(frame,58,28,"UNDO")
undoButton:SetPoint("LEFT",sync,"RIGHT",6,0)
undoButton:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
undoButton:SetScript("OnClick",function()
local entry=lastRemovedEntry
if not entry then
return
end
if GSI.GetEntry(entry.name) then
lastRemovedEntry=nil
SetUndoButtonEnabled(false)
if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffGuildSharedIgnore|r: Cannot undo removal because "..entry.name.." is already on the list.")
end
return
end
if GSI.AddPlayer(entry.name,entry.note,entry.addedBy,entry.category) then
lastRemovedEntry=nil
SetUndoButtonEnabled(false)
AnnounceAddedPlayer(entry.name,entry.note,entry.category,"added")
RefreshList()
end
end)
undoButton:SetScript("OnEnter",function(self)
if self:IsEnabled() then
SetBackdropFill(self,{0.075,0.12,0.17,1})
SetBackdropBorder(self,ACCENT)
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:SetText("Undo last removal",1,1,1)
GameTooltip:AddLine("Restore the most recently removed player.",0.75,0.78,0.82,true)
GameTooltip:Show()
end
end)
undoButton:SetScript("OnLeave",function()
GameTooltip:Hide()
UpdateUndoButtonAppearance(undoButton:IsEnabled())
end)
SetUndoButtonEnabled(false)
announceCheck=CreateFrame("CheckButton",nil,settingsPanel)
announceCheck:SetSize(26,26)
announceCheck:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",12,-101)
announceCheck:SetFrameLevel(settingsPanel:GetFrameLevel()+2)
announceCheck:EnableMouse(true)
ApplyBackdrop(announceCheck,BG,BORDER)
local check=announceCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
check:SetAllPoints()
check:SetText("X")
check:SetJustifyH("CENTER")
check:SetJustifyV("MIDDLE")
SetFontStringColor(check,GREEN[1],GREEN[2],GREEN[3])
announceCheck.mark=check
announceText=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
announceText:SetPoint("LEFT",announceCheck,"RIGHT",7,0)
announceText:SetText("Announce")
SetFontStringColor(announceText,TEXT[1],TEXT[2],TEXT[3])
SetToggleTooltip(announceCheck,announceCheck,"Guild announcements","When enabled, adding, updating, or removing a player announces the change in guild chat.")
announceCheck:SetChecked(GuildSharedIgnoreDB.announceGuild)
check:SetShown(GuildSharedIgnoreDB.announceGuild)
announceCheck:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
announceCheck:SetScript("OnClick",function(self)
local checked=self:GetChecked()
GuildSharedIgnoreDB.announceGuild=checked and true or false
check:SetShown(checked)
if checked then
SetFontStringColor(check,GREEN[1],GREEN[2],GREEN[3])
end
end)
muteCheck=CreateFrame("CheckButton",nil,settingsPanel)
muteCheck:SetSize(26,26)
muteCheck:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",12,-135)
muteCheck:SetFrameLevel(settingsPanel:GetFrameLevel()+2)
muteCheck:EnableMouse(true)
ApplyBackdrop(muteCheck,BG,BORDER)
local muteMark=muteCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
muteMark:SetAllPoints()
muteMark:SetText("X")
muteMark:SetJustifyH("CENTER")
muteMark:SetJustifyV("MIDDLE")
SetFontStringColor(muteMark,GREEN[1],GREEN[2],GREEN[3])
muteCheck.mark=muteMark
muteText=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
muteText:SetPoint("LEFT",muteCheck,"RIGHT",7,0)
muteText:SetText("Mute")
SetFontStringColor(muteText,TEXT[1],TEXT[2],TEXT[3])
SetToggleTooltip(muteCheck,muteCheck,"Mute addon messages","Suppresses GuildSharedIgnore chat messages. Warnings about listed players in your group will still be shown.")
muteCheck:SetChecked(GuildSharedIgnoreDB.muteMessages)
muteMark:SetShown(GuildSharedIgnoreDB.muteMessages)
muteCheck:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
muteCheck:SetScript("OnClick",function(self)
local checked=self:GetChecked()
GuildSharedIgnoreDB.muteMessages=checked and true or false
muteMark:SetShown(checked)
if checked then
SetFontStringColor(muteMark,GREEN[1],GREEN[2],GREEN[3])
end
end)
deleteConfirmCheck=CreateFrame("CheckButton",nil,settingsPanel)
deleteConfirmCheck:SetSize(26,26)
deleteConfirmCheck:SetPoint("TOPLEFT",settingsPanel,"TOPLEFT",12,-169)
deleteConfirmCheck:SetFrameLevel(settingsPanel:GetFrameLevel()+2)
deleteConfirmCheck:EnableMouse(true)
ApplyBackdrop(deleteConfirmCheck,BG,BORDER)
local deleteConfirmMark=deleteConfirmCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
deleteConfirmMark:SetAllPoints()
deleteConfirmMark:SetText("X")
deleteConfirmMark:SetJustifyH("CENTER")
deleteConfirmMark:SetJustifyV("MIDDLE")
SetFontStringColor(deleteConfirmMark,GREEN[1],GREEN[2],GREEN[3])
deleteConfirmCheck.mark=deleteConfirmMark
deleteConfirmText=settingsPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
deleteConfirmText:SetPoint("LEFT",deleteConfirmCheck,"RIGHT",7,0)
deleteConfirmText:SetText("Confirm delete")
SetFontStringColor(deleteConfirmText,TEXT[1],TEXT[2],TEXT[3])
SetToggleTooltip(deleteConfirmCheck,deleteConfirmCheck,"Confirm before deleting","Show a confirmation dialog before removing a player from the shared list.")
deleteConfirmCheck:SetChecked(GuildSharedIgnoreDB.confirmDelete)
deleteConfirmMark:SetShown(GuildSharedIgnoreDB.confirmDelete)
deleteConfirmCheck:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
deleteConfirmCheck:SetScript("OnClick",function(self)
local checked=self:GetChecked()
GuildSharedIgnoreDB.confirmDelete=checked and true or false
deleteConfirmMark:SetShown(checked)
if checked then
SetFontStringColor(deleteConfirmMark,GREEN[1],GREEN[2],GREEN[3])
end
end)
local tableHeader=CreateFrame("Frame",nil,frame)
tableHeader:SetPoint("TOPLEFT",frame,"TOPLEFT",9,-85)
tableHeader:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-27,-85)
tableHeader:SetHeight(25)
tableHeader:EnableMouse(true)
tableHeader:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
ApplyBackdrop(tableHeader,PANEL2,BORDER)
frame.tableHeader=tableHeader
local hPlayer=tableHeader:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
local hAdded=tableHeader:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
local hCategory=tableHeader:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
local hNote=tableHeader:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
local hDate=tableHeader:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
hPlayer:SetText("PLAYER")
hAdded:SetText("ADDED BY")
hCategory:SetText("CATEGORY")
hNote:SetText("NOTE")
hDate:SetText("DATE")
SetFontStringColor(hPlayer,MUTED[1],MUTED[2],MUTED[3])
SetFontStringColor(hAdded,MUTED[1],MUTED[2],MUTED[3])
SetFontStringColor(hCategory,MUTED[1],MUTED[2],MUTED[3])
SetFontStringColor(hNote,MUTED[1],MUTED[2],MUTED[3])
SetFontStringColor(hDate,MUTED[1],MUTED[2],MUTED[3])
hDate:SetJustifyH("CENTER")
frame.hPlayer=hPlayer
frame.hAdded=hAdded
frame.hCategory=hCategory
frame.hNote=hNote
frame.hDate=hDate
frame.sortPlayer=MakeHeaderButton(tableHeader,hPlayer,"player")
frame.sortAdded=MakeHeaderButton(tableHeader,hAdded,"addedBy")
frame.sortCategory=MakeHeaderButton(tableHeader,hCategory,"category")
frame.sortDate=MakeHeaderButton(tableHeader,hDate,"date")
scrollFrame=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",frame,"TOPLEFT",9,-113)
scrollFrame:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-27,31)
scrollFrame:EnableMouse(true)
scrollFrame:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
scrollChild=CreateFrame("Frame",nil,scrollFrame)
scrollChild:SetWidth(scrollFrame:GetWidth())
scrollChild:SetHeight(1)
scrollChild:EnableMouse(true)
scrollChild:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
scrollFrame:SetScrollChild(scrollChild)
scrollFrame:SetScript("OnSizeChanged",function()
UpdateColumns()
RefreshList()
end)
local footerAuthorLabel=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerAuthorLabel:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",12,9)
footerAuthorLabel:SetText("Author:")
SetFontStringColor(footerAuthorLabel,MUTED[1],MUTED[2],MUTED[3])
local footerAuthor=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerAuthor:SetPoint("LEFT",footerAuthorLabel,"RIGHT",4,0)
footerAuthor:SetText("Avarishd")
SetFontStringColor(footerAuthor,HUNTER_GREEN[1],HUNTER_GREEN[2],HUNTER_GREEN[3])
local footerSeparator=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerSeparator:SetPoint("LEFT",footerAuthor,"RIGHT",6,0)
footerSeparator:SetText("•")
SetFontStringColor(footerSeparator,MUTED[1],MUTED[2],MUTED[3])
footerGithub=CreateFrame("Button",nil,frame)
footerGithub:SetSize(115,18)
footerGithub:SetPoint("LEFT",footerSeparator,"RIGHT",6,0)
footerGithub:SetFrameLevel(frame:GetFrameLevel()+5)
footerGithub:EnableMouse(true)
local footerGithubText=footerGithub:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerGithubText:SetAllPoints()
footerGithubText:SetText("github.com/avarishd")
footerGithubText:SetJustifyH("LEFT")
SetFontStringColor(footerGithubText,SKY_BLUE[1],SKY_BLUE[2],SKY_BLUE[3])
footerGithub:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
end
end)
footerGithub:SetScript("OnEnter",function(self)
SetFontStringColor(footerGithubText,0.60,0.85,1.00)
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:SetText("Click to copy GitHub URL",1,1,1)
GameTooltip:Show()
end)
footerGithub:SetScript("OnLeave",function()
SetFontStringColor(footerGithubText,SKY_BLUE[1],SKY_BLUE[2],SKY_BLUE[3])
GameTooltip:Hide()
end)
footerGithub:SetScript("OnClick",function()
ShowGitHubCopyBox()
end)
local footerSeparator2=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerSeparator2:SetPoint("LEFT",footerGithub,"RIGHT",6,0)
footerSeparator2:SetText("•")
SetFontStringColor(footerSeparator2,MUTED[1],MUTED[2],MUTED[3])
local footerHelp=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
footerHelp:SetPoint("LEFT",footerSeparator2,"RIGHT",6,0)
footerHelp:SetText("Click a note to edit")
SetFontStringColor(footerHelp,MUTED[1],MUTED[2],MUTED[3])
local count=frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
count:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-32,9)
count:SetText("YOU: 0 TOTAL: 0")
SetFontStringColor(count,MUTED[1],MUTED[2],MUTED[3])
frame.count=count
frame:SetResizable(true)
local minimumWidth=700
local controlsRight=undoButton:GetRight()
local frameLeft=frame:GetLeft()
if controlsRight and frameLeft then
local requiredWidth=controlsRight-frameLeft+12
if requiredWidth>minimumWidth then
minimumWidth=requiredWidth
end
end
local screenWidth=UIParent:GetWidth()
local screenHeight=UIParent:GetHeight()
local maximumWidth=math.floor(screenWidth*0.50)
local maximumHeight=math.floor(screenHeight*0.50)
if maximumWidth<minimumWidth then
minimumWidth=maximumWidth
end
if maximumHeight<340 then
maximumHeight=340
end
frame:SetMinResize(math.floor(minimumWidth),340)
frame:SetMaxResize(maximumWidth,maximumHeight)
local resize=CreateFrame("Button",nil,frame)
resize:SetSize(24,24)
resize:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-1,1)
resize:SetFrameLevel(110)
resize:EnableMouse(true)
resize:SetScript("OnMouseDown",function(self,button)
if button=="RightButton" then
ClearInputFields()
elseif button=="LeftButton" then
frame:StartSizing("BOTTOMRIGHT")
end
end)
resize:SetScript("OnMouseUp",function(self,button)
if button=="LeftButton" then
frame:StopMovingOrSizing()
UpdateColumns()
RefreshList()
end
end)
CreateNoteEditor()
UpdateSortHeaders()
UpdateColumns()
RefreshList()
UpdateVersionDisplay()
UpdateSyncStatus()
if C_Timer and C_Timer.NewTicker then
C_Timer.NewTicker(1,function()
if frame and frame:IsShown() then
UpdateSyncStatus()
end
end)
end
frame:Hide()
end
GSI.CreateUI=CreateUI
GSI.GetFrame=function()
return frame
end
GSI.ToggleUI=function()
if not frame then
CreateUI()
end
if frame:IsShown() then
CloseCategoryMenu()
frame:Hide()
else
frame:Show()
frame:Raise()
frame:EnableKeyboard(true)
frame:SetPropagateKeyboardInput(true)
RefreshList()
UpdateVersionDisplay()
UpdateSyncStatus()
end
end