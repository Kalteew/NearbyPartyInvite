-- NearbyPartyInvite main addon file
-- Handles minimap button, combat log scanning, popup confirmation, and chat commands

local NPI_AddonName, NPI_Addon = ...
NearbyPartyInvite = NPI_Addon

local NPI_Frame = CreateFrame("Frame")
NPI_Addon.frame = NPI_Frame

NPI_Addon.invited = {}
NPI_Addon.ignored = {}
NPI_Addon.pendingInvites = {}
NPI_Addon.enabled = false
NPI_Settings = NPI_Settings or {}
if NPI_Settings.whisperEnabled == nil then
    NPI_Settings.whisperEnabled = false
end
NPI_Settings.whisperMessage = NPI_Settings.whisperMessage or ""
if NPI_Settings.triggerMouseover == nil then
    NPI_Settings.triggerMouseover = true
end
if NPI_Settings.triggerTarget == nil then
    NPI_Settings.triggerTarget = true
end
local NPI_PendingInvite = nil
local NPI_PlayerName, NPI_PlayerRealm = UnitName("player")
local NPI_PlayerFullName = NPI_PlayerRealm and NPI_PlayerRealm ~= "" and NPI_PlayerName .. "-" .. NPI_PlayerRealm or NPI_PlayerName
local NPI_PlayerFaction = UnitFactionGroup("player")
local NPI_PendingWhisper = nil
local NPI_GroupFullWarned = false

-- Forward declarations for options panel and category
local NPI_Options, NPI_SettingsCategory
local NPI_EnableCheck, NPI_WhisperCheck, NPI_MessageInput, NPI_MouseoverCheck, NPI_TargetCheck
local NPI_IsPlayerInGroup

--
-- Attempt to invite a player by name after basic checks
local function NPI_StartInvite(NPI_TargetName)
    if NPI_Addon.invited[NPI_TargetName] or NPI_Addon.ignored[NPI_TargetName] then return end
    if NPI_IsPlayerInGroup(NPI_TargetName) then return end

    NPI_PendingInvite = NPI_TargetName
    StaticPopup_Show("NPI_CONFIRM_INVITE", NPI_TargetName, nil, {name = NPI_TargetName})
end

local function NPI_GetPendingInviteCount()
    local NPI_Count = 0
    for NPI_Name in pairs(NPI_Addon.pendingInvites) do
        if NPI_IsPlayerInGroup(NPI_Name) then
            NPI_Addon.pendingInvites[NPI_Name] = nil
        else
            NPI_Count = NPI_Count + 1
        end
    end
    return NPI_Count
end

local function NPI_IsGroupFull()
    local NPI_GroupSize = GetNumGroupMembers()
    if NPI_GroupSize == 0 then NPI_GroupSize = 1 end
    NPI_GroupSize = NPI_GroupSize + NPI_GetPendingInviteCount()
    return NPI_GroupSize >= 5
end

function NPI_IsPlayerInGroup(NPI_TargetName)
    if not IsInGroup() then return false end

    local NPI_Count = GetNumGroupMembers()
    if IsInRaid() then
        for NPI_Index = 1, NPI_Count do
            local NPI_Unit = "raid" .. NPI_Index
            if UnitExists(NPI_Unit) then
                local NPI_Name, NPI_Realm = UnitName(NPI_Unit)
                local NPI_FullName = NPI_Realm and NPI_Realm ~= "" and NPI_Name .. "-" .. NPI_Realm or NPI_Name
                if NPI_FullName == NPI_TargetName then
                    return true
                end
            end
        end
    else
        for NPI_Index = 1, NPI_Count - 1 do
            local NPI_Unit = "party" .. NPI_Index
            if UnitExists(NPI_Unit) then
                local NPI_Name, NPI_Realm = UnitName(NPI_Unit)
                local NPI_FullName = NPI_Realm and NPI_Realm ~= "" and NPI_Name .. "-" .. NPI_Realm or NPI_Name
                if NPI_FullName == NPI_TargetName then
                    return true
                end
            end
        end
    end

    return false
end

-- Enable or disable auto-invite mode
function NPI_Addon:Enable()
    if not self.enabled then
        self.enabled = true
        NPI_Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        if NPI_Settings.triggerMouseover then
            NPI_Frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        end
        if NPI_Settings.triggerTarget then
            NPI_Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        end
        NPI_Frame:RegisterEvent("CHAT_MSG_SYSTEM")
        NPI_Frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        if self.minimapButton and self.minimapButton.icon then
            self.minimapButton.icon:SetDesaturated(false)
        end
        if NPI_EnableCheck then
            NPI_EnableCheck:SetChecked(true)
        end
    end
end

function NPI_Addon:Disable()
    if self.enabled then
        self.enabled = false
        NPI_Frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        NPI_Frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        NPI_Frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        NPI_Frame:UnregisterEvent("CHAT_MSG_SYSTEM")
        NPI_Frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        if self.minimapButton and self.minimapButton.icon then
            self.minimapButton.icon:SetDesaturated(true)
        end
        if NPI_EnableCheck then
            NPI_EnableCheck:SetChecked(false)
        end
    end
end

function NPI_Addon:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
    DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Auto-invite " .. (self.enabled and "enabled" or "disabled") .. ".")
end

-- Confirmation popup
StaticPopupDialogs["NPI_CONFIRM_INVITE"] = {
    text = "Invite %s to your group?",
    button1 = YES,
    button2 = NO,
    button3 = "Disable Addon",
      OnAccept = function(self, data)
          InviteUnit(data.name)
          NPI_Addon.invited[data.name] = true
          NPI_Addon.pendingInvites[data.name] = true
          C_Timer.After(60, function()
              if not NPI_IsPlayerInGroup(data.name) then
                  NPI_Addon.pendingInvites[data.name] = nil
              end
          end)
          DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Invited " .. data.name .. ".")
          if NPI_Settings.whisperEnabled and NPI_Settings.whisperMessage ~= "" then
              NPI_PendingWhisper = data.name
              C_Timer.After(1, function()
                  if NPI_PendingWhisper == data.name then
                    SendChatMessage("NearbyPartyInvite: " .. NPI_Settings.whisperMessage, "WHISPER", nil, data.name)
                    NPI_PendingWhisper = nil
                end
            end)
        else
            NPI_PendingWhisper = nil
        end
          NPI_PendingInvite = nil
      end,
    OnCancel = function(_, data)
        NPI_Addon.ignored[data.name] = true
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Ignored " .. data.name .. ".")
      NPI_PendingInvite = nil
  end,
    OnAlt = function()
        NPI_Addon:Disable()
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Auto-invite disabled.")
        NPI_PendingInvite = nil
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- Combat log handler
local NPI_bitBand = bit.band
function NPI_Frame:COMBAT_LOG_EVENT_UNFILTERED()
    if not NPI_Addon.enabled or NPI_PendingInvite then return end
    if NPI_IsGroupFull() then
        if not NPI_GroupFullWarned then
            DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Group is full. No invitations sent.")
            NPI_GroupFullWarned = true
        end
        return
    else
        NPI_GroupFullWarned = false
    end

    local _, _, _, NPI_SourceGUID, NPI_SourceName, NPI_SourceFlags = CombatLogGetCurrentEventInfo()
    if not NPI_SourceName or NPI_SourceName == NPI_PlayerFullName then return end

    if NPI_bitBand(NPI_SourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then return end
    if NPI_bitBand(NPI_SourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then return end

    NPI_StartInvite(NPI_SourceName)
end

local function NPI_CheckUnit(NPI_Unit)
    if not UnitExists(NPI_Unit) or not UnitIsPlayer(NPI_Unit) then return end
    local NPI_Name, NPI_Realm = UnitName(NPI_Unit)
    local NPI_FullName = NPI_Realm and NPI_Realm ~= "" and NPI_Name .. "-" .. NPI_Realm or NPI_Name
    if NPI_FullName == NPI_PlayerFullName then return end
    if UnitFactionGroup(NPI_Unit) ~= NPI_PlayerFaction then return end
    NPI_StartInvite(NPI_FullName)
end

function NPI_Frame:UPDATE_MOUSEOVER_UNIT()
    if not NPI_Addon.enabled or NPI_PendingInvite then return end
    if NPI_IsGroupFull() then
        if not NPI_GroupFullWarned then
            DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Group is full. No invitations sent.")
            NPI_GroupFullWarned = true
        end
        return
    else
        NPI_GroupFullWarned = false
    end
    NPI_CheckUnit("mouseover")
end

function NPI_Frame:PLAYER_TARGET_CHANGED()
    if not NPI_Addon.enabled or NPI_PendingInvite then return end
    if NPI_IsGroupFull() then
        if not NPI_GroupFullWarned then
            DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Group is full. No invitations sent.")
            NPI_GroupFullWarned = true
        end
        return
    else
        NPI_GroupFullWarned = false
    end
    NPI_CheckUnit("target")
end

function NPI_Frame:CHAT_MSG_SYSTEM(msg)
    -- ERR_ALREADY_IN_GROUP_S is a localized global provided by the WoW client
    if NPI_PendingWhisper and msg == ERR_ALREADY_IN_GROUP_S:format(NPI_PendingWhisper) then
        NPI_PendingWhisper = nil
    end
    for NPI_Name in pairs(NPI_Addon.pendingInvites) do
        if msg == ERR_DECLINE_GROUP_S:format(NPI_Name) or msg == ERR_ALREADY_IN_GROUP_S:format(NPI_Name) then
            NPI_Addon.pendingInvites[NPI_Name] = nil
            break
        end
    end
end

function NPI_Frame:GROUP_ROSTER_UPDATE()
    for NPI_Name in pairs(NPI_Addon.pendingInvites) do
        if NPI_IsPlayerInGroup(NPI_Name) then
            NPI_Addon.pendingInvites[NPI_Name] = nil
        end
    end
end

NPI_Frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

-- Minimap button setup
local NPI_MinimapButton = CreateFrame("Button", "NPI_MinimapButton", Minimap)
NPI_Addon.minimapButton = NPI_MinimapButton
NPI_MinimapButton:SetFrameStrata("MEDIUM")
NPI_MinimapButton:SetSize(31, 31)
NPI_MinimapButton:SetFrameLevel(8)
NPI_MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
NPI_MinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

local NPI_MinimapOverlay = NPI_MinimapButton:CreateTexture(nil, "OVERLAY")
NPI_MinimapOverlay:SetSize(53, 53)
NPI_MinimapOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
NPI_MinimapOverlay:SetPoint("TOPLEFT")

local NPI_MinimapIcon = NPI_MinimapButton:CreateTexture(nil, "BACKGROUND")
NPI_MinimapButton.icon = NPI_MinimapIcon
NPI_MinimapIcon:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
NPI_MinimapIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
NPI_MinimapIcon:SetSize(20, 20)
NPI_MinimapIcon:SetPoint("CENTER")
NPI_MinimapIcon:SetDesaturated(true)

NPI_MinimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(NPI_SettingsCategory and NPI_SettingsCategory.ID or "NearbyPartyInvite")
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(NPI_Options)
        end
    else
        NPI_Addon:Toggle()
    end
end)

NPI_MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("NearbyPartyInvite")
    GameTooltip:AddLine("Left-click to toggle auto-invite mode", 1, 1, 1)
    GameTooltip:AddLine("Right-click to open settings", 1, 1, 1)
    GameTooltip:Show()
end)

NPI_MinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Options panel
NPI_Options = CreateFrame("Frame", "NPI_Options")
NPI_Options.name = "NearbyPartyInvite"

NPI_EnableCheck = CreateFrame("CheckButton", "NPI_EnableCheck", NPI_Options, "InterfaceOptionsCheckButtonTemplate")
NPI_EnableCheck:SetPoint("TOPLEFT", 16, -16)
NPI_EnableCheck.Text:SetText("Enable auto-invite")
NPI_EnableCheck:SetChecked(NPI_Addon.enabled)
NPI_EnableCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
        NPI_Addon:Enable()
    else
        NPI_Addon:Disable()
    end
end)

NPI_WhisperCheck = CreateFrame("CheckButton", "NPI_WhisperCheck", NPI_Options, "InterfaceOptionsCheckButtonTemplate")
NPI_WhisperCheck:SetPoint("TOPLEFT", NPI_EnableCheck, "BOTTOMLEFT", 0, -8)
NPI_WhisperCheck.Text:SetText("Enable whisper message")
NPI_WhisperCheck:SetChecked(NPI_Settings.whisperEnabled)

NPI_MessageInput = CreateFrame("EditBox", "NPI_MessageInput", NPI_Options, "InputBoxTemplate")
NPI_MessageInput:SetSize(220, 25)
NPI_MessageInput:SetAutoFocus(false)
NPI_MessageInput:SetPoint("TOPLEFT", NPI_WhisperCheck, "BOTTOMLEFT", 30, -8)
NPI_MessageInput:SetText(NPI_Settings.whisperMessage)
NPI_MessageInput:SetScript("OnEnterPressed", function(self)
    NPI_Settings.whisperMessage = self:GetText()
    self:ClearFocus()
end)
NPI_MessageInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
NPI_MessageInput:SetScript("OnEditFocusLost", function(self)
    NPI_Settings.whisperMessage = self:GetText()
end)

local function NPI_UpdateMessageInput()
    if NPI_WhisperCheck:GetChecked() then
        NPI_MessageInput:Show()
    else
        NPI_MessageInput:Hide()
    end
end

NPI_WhisperCheck:SetScript("OnClick", function(self)
    NPI_Settings.whisperEnabled = self:GetChecked()
    NPI_UpdateMessageInput()
end)

NPI_UpdateMessageInput()

NPI_MouseoverCheck = CreateFrame("CheckButton", "NPI_MouseoverCheck", NPI_Options, "InterfaceOptionsCheckButtonTemplate")
NPI_MouseoverCheck:SetPoint("TOPLEFT", NPI_MessageInput, "BOTTOMLEFT", -30, -8)
NPI_MouseoverCheck.Text:SetText("Scan on mouseover")
NPI_MouseoverCheck:SetChecked(NPI_Settings.triggerMouseover)
NPI_MouseoverCheck:SetScript("OnClick", function(self)
    NPI_Settings.triggerMouseover = self:GetChecked()
    if NPI_Addon.enabled then
        if self:GetChecked() then
            NPI_Frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        else
            NPI_Frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        end
    end
end)

NPI_TargetCheck = CreateFrame("CheckButton", "NPI_TargetCheck", NPI_Options, "InterfaceOptionsCheckButtonTemplate")
NPI_TargetCheck:SetPoint("TOPLEFT", NPI_MouseoverCheck, "BOTTOMLEFT", 0, -8)
NPI_TargetCheck.Text:SetText("Scan on target change")
NPI_TargetCheck:SetChecked(NPI_Settings.triggerTarget)
NPI_TargetCheck:SetScript("OnClick", function(self)
    NPI_Settings.triggerTarget = self:GetChecked()
    if NPI_Addon.enabled then
        if self:GetChecked() then
            NPI_Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        else
            NPI_Frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        end
    end
end)

NPI_Options:HookScript("OnShow", function()
    NPI_EnableCheck:SetChecked(NPI_Addon.enabled)
    NPI_WhisperCheck:SetChecked(NPI_Settings.whisperEnabled)
    NPI_MessageInput:SetText(NPI_Settings.whisperMessage)
    NPI_UpdateMessageInput()
    NPI_MouseoverCheck:SetChecked(NPI_Settings.triggerMouseover)
    NPI_TargetCheck:SetChecked(NPI_Settings.triggerTarget)
end)
if Settings and Settings.RegisterAddOnCategory then
    NPI_SettingsCategory = Settings.RegisterCanvasLayoutCategory(NPI_Options, NPI_Options.name)
    NPI_SettingsCategory.ID = NPI_Options.name
    Settings.RegisterAddOnCategory(NPI_SettingsCategory)
else
    InterfaceOptions_AddCategory(NPI_Options)
end

-- Chat commands
SLASH_NPI1 = "/npi"
SlashCmdList["NPI"] = function(NPI_Command)
    local NPI_Cmd, NPI_Rest = (NPI_Command or ""):match("^(%S*)%s*(.-)$")
    NPI_Cmd = string.lower(NPI_Cmd)
    if NPI_Cmd == "toggle" then
        NPI_Addon:Toggle()
    elseif NPI_Cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Auto-invite is " .. (NPI_Addon.enabled and "enabled" or "disabled") .. ".")
    elseif NPI_Cmd == "message" then
        if NPI_Rest == "" then
            if NPI_Settings.whisperEnabled and NPI_Settings.whisperMessage ~= "" then
                DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Current whisper message: " .. NPI_Settings.whisperMessage)
            else
                DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: No whisper message set.")
            end
        else
            NPI_Settings.whisperMessage = NPI_Rest
            NPI_Settings.whisperEnabled = true
            DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Whisper message set to '" .. NPI_Rest .. "'.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite commands: /npi toggle, /npi status, /npi message <text>")
    end
end

