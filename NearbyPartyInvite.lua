-- NearbyPartyInvite main addon file
-- Handles minimap button, combat log scanning, popup confirmation, and chat commands

local NPI_AddonName, NPI_Addon = ...
NearbyPartyInvite = NPI_Addon

local NPI_Frame = CreateFrame("Frame")
NPI_Addon.frame = NPI_Frame

NPI_Addon.invited = {}
NPI_Addon.ignored = {}
NPI_Addon.enabled = false
NPI_Settings = NPI_Settings or {}
if NPI_Settings.whisperEnabled == nil then
    NPI_Settings.whisperEnabled = false
end
NPI_Settings.whisperMessage = NPI_Settings.whisperMessage or ""
local NPI_PendingInvite = nil
local NPI_PlayerName, NPI_PlayerRealm = UnitName("player")
local NPI_PlayerFullName = NPI_PlayerRealm and NPI_PlayerRealm ~= "" and NPI_PlayerName .. "-" .. NPI_PlayerRealm or NPI_PlayerName

-- Forward declarations for options panel and category
local NPI_Options, NPI_SettingsCategory
local NPI_EnableCheck, NPI_WhisperCheck, NPI_MessageInput

-- Utility: find a unitID by player name
local function NPI_FindUnitByName(NPI_TargetName)
    local NPI_Units = {"target", "focus", "mouseover"}
    for NPI_Index = 1, 40 do
        NPI_Units[#NPI_Units + 1] = "nameplate" .. NPI_Index
    end
    for _, NPI_Unit in ipairs(NPI_Units) do
        if UnitExists(NPI_Unit) then
            local NPI_UnitName, NPI_UnitRealm = UnitName(NPI_Unit)
            local NPI_FullName = NPI_UnitRealm and NPI_UnitRealm ~= "" and NPI_UnitName .. "-" .. NPI_UnitRealm or NPI_UnitName
            if NPI_FullName == NPI_TargetName then
                return NPI_Unit
            end
        end
    end
    return nil
end

local function NPI_IsPlayerInGroup(NPI_TargetName)
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
    OnAccept = function(self, data)
        InviteUnit(data.name)
        NPI_Addon.invited[data.name] = true
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Invited " .. data.name .. ".")
        if NPI_Settings.whisperEnabled and NPI_Settings.whisperMessage ~= "" then
            SendChatMessage("NearbyPartyInvite: " .. NPI_Settings.whisperMessage, "WHISPER", nil, data.name)
        end
        NPI_PendingInvite = nil
    end,
    OnCancel = function(_, data)
        NPI_Addon.ignored[data.name] = true
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Ignored " .. data.name .. ".")
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

    local _, _, _, NPI_SourceGUID, NPI_SourceName, NPI_SourceFlags = CombatLogGetCurrentEventInfo()
    if not NPI_SourceName or NPI_SourceName == NPI_PlayerFullName then return end

    if NPI_bitBand(NPI_SourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then return end
    if NPI_Addon.invited[NPI_SourceName] or NPI_Addon.ignored[NPI_SourceName] then return end
    if NPI_IsPlayerInGroup(NPI_SourceName) then return end

    local NPI_GroupSize = GetNumGroupMembers()
    if NPI_GroupSize == 0 then NPI_GroupSize = 1 end
    if NPI_GroupSize >= 5 then
        DEFAULT_CHAT_FRAME:AddMessage("NearbyPartyInvite: Group is full. No invitations sent.")
        return
    end

    local NPI_Unit = NPI_FindUnitByName(NPI_SourceName)
    if not NPI_Unit or not UnitIsFriend("player", NPI_Unit) then return end
    if not CheckInteractDistance(NPI_Unit, 1) then return end

    NPI_PendingInvite = NPI_SourceName
    StaticPopup_Show("NPI_CONFIRM_INVITE", NPI_SourceName, nil, {name = NPI_SourceName})
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
NPI_Options:HookScript("OnShow", function()
    NPI_EnableCheck:SetChecked(NPI_Addon.enabled)
    NPI_WhisperCheck:SetChecked(NPI_Settings.whisperEnabled)
    NPI_MessageInput:SetText(NPI_Settings.whisperMessage)
    NPI_UpdateMessageInput()
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

