-- EasyPartyInvite main addon file
-- Handles minimap button, combat log scanning, popup confirmation, and chat commands

local EPI_AddonName, EPI_Addon = ...
EasyPartyInvite = EPI_Addon

local EPI_Frame = CreateFrame("Frame")
EPI_Addon.frame = EPI_Frame

EPI_Addon.invited = {}
EPI_Addon.ignored = {}
EPI_Addon.enabled = false
EPI_Settings = EPI_Settings or {}
if EPI_Settings.whisperEnabled == nil then
    EPI_Settings.whisperEnabled = false
end
EPI_Settings.whisperMessage = EPI_Settings.whisperMessage or ""
local EPI_PendingInvite = nil
local EPI_PlayerName, EPI_PlayerRealm = UnitName("player")
local EPI_PlayerFullName = EPI_PlayerRealm and EPI_PlayerRealm ~= "" and EPI_PlayerName .. "-" .. EPI_PlayerRealm or EPI_PlayerName

-- Forward declarations for options panel and category
local EPI_Options, EPI_SettingsCategory
local EPI_EnableCheck, EPI_WhisperCheck, EPI_MessageInput

-- Utility: find a unitID by player name
local function EPI_FindUnitByName(EPI_TargetName)
    local EPI_Units = {"target", "focus", "mouseover"}
    for EPI_Index = 1, 40 do
        EPI_Units[#EPI_Units + 1] = "nameplate" .. EPI_Index
    end
    for _, EPI_Unit in ipairs(EPI_Units) do
        if UnitExists(EPI_Unit) then
            local EPI_UnitName, EPI_UnitRealm = UnitName(EPI_Unit)
            local EPI_FullName = EPI_UnitRealm and EPI_UnitRealm ~= "" and EPI_UnitName .. "-" .. EPI_UnitRealm or EPI_UnitName
            if EPI_FullName == EPI_TargetName then
                return EPI_Unit
            end
        end
    end
    return nil
end

local function EPI_IsPlayerInGroup(EPI_TargetName)
    if not IsInGroup() then return false end

    local EPI_Count = GetNumGroupMembers()
    if IsInRaid() then
        for EPI_Index = 1, EPI_Count do
            local EPI_Unit = "raid" .. EPI_Index
            if UnitExists(EPI_Unit) then
                local EPI_Name, EPI_Realm = UnitName(EPI_Unit)
                local EPI_FullName = EPI_Realm and EPI_Realm ~= "" and EPI_Name .. "-" .. EPI_Realm or EPI_Name
                if EPI_FullName == EPI_TargetName then
                    return true
                end
            end
        end
    else
        for EPI_Index = 1, EPI_Count - 1 do
            local EPI_Unit = "party" .. EPI_Index
            if UnitExists(EPI_Unit) then
                local EPI_Name, EPI_Realm = UnitName(EPI_Unit)
                local EPI_FullName = EPI_Realm and EPI_Realm ~= "" and EPI_Name .. "-" .. EPI_Realm or EPI_Name
                if EPI_FullName == EPI_TargetName then
                    return true
                end
            end
        end
    end

    return false
end

-- Enable or disable auto-invite mode
function EPI_Addon:Enable()
    if not self.enabled then
        self.enabled = true
        EPI_Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        if self.minimapButton and self.minimapButton.icon then
            self.minimapButton.icon:SetDesaturated(false)
        end
        if EPI_EnableCheck then
            EPI_EnableCheck:SetChecked(true)
        end
    end
end

function EPI_Addon:Disable()
    if self.enabled then
        self.enabled = false
        EPI_Frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        if self.minimapButton and self.minimapButton.icon then
            self.minimapButton.icon:SetDesaturated(true)
        end
        if EPI_EnableCheck then
            EPI_EnableCheck:SetChecked(false)
        end
    end
end

function EPI_Addon:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
    DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Auto-invite " .. (self.enabled and "enabled" or "disabled") .. ".")
end

-- Confirmation popup
StaticPopupDialogs["EPI_CONFIRM_INVITE"] = {
    text = "Invite %s to your group?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        InviteUnit(data.name)
        EPI_Addon.invited[data.name] = true
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Invited " .. data.name .. ".")
        if EPI_Settings.whisperEnabled and EPI_Settings.whisperMessage ~= "" then
            SendChatMessage("EasyPartyInvite: " .. EPI_Settings.whisperMessage, "WHISPER", nil, data.name)
        end
        EPI_PendingInvite = nil
    end,
    OnCancel = function(_, data)
        EPI_Addon.ignored[data.name] = true
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Ignored " .. data.name .. ".")
        EPI_PendingInvite = nil
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- Combat log handler
local EPI_bitBand = bit.band
function EPI_Frame:COMBAT_LOG_EVENT_UNFILTERED()
    if not EPI_Addon.enabled or EPI_PendingInvite then return end

    local _, _, _, EPI_SourceGUID, EPI_SourceName, EPI_SourceFlags = CombatLogGetCurrentEventInfo()
    if not EPI_SourceName or EPI_SourceName == EPI_PlayerFullName then return end

    if EPI_bitBand(EPI_SourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then return end
    if EPI_Addon.invited[EPI_SourceName] or EPI_Addon.ignored[EPI_SourceName] then return end
    if EPI_IsPlayerInGroup(EPI_SourceName) then return end

    local EPI_GroupSize = GetNumGroupMembers()
    if EPI_GroupSize == 0 then EPI_GroupSize = 1 end
    if EPI_GroupSize >= 5 then
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Group is full. No invitations sent.")
        return
    end

    local EPI_Unit = EPI_FindUnitByName(EPI_SourceName)
    if not EPI_Unit or not UnitIsFriend("player", EPI_Unit) then return end
    if not CheckInteractDistance(EPI_Unit, 1) then return end

    EPI_PendingInvite = EPI_SourceName
    StaticPopup_Show("EPI_CONFIRM_INVITE", EPI_SourceName, nil, {name = EPI_SourceName})
end

EPI_Frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

-- Minimap button setup
local EPI_MinimapButton = CreateFrame("Button", "EPI_MinimapButton", Minimap)
EPI_Addon.minimapButton = EPI_MinimapButton
EPI_MinimapButton:SetFrameStrata("MEDIUM")
EPI_MinimapButton:SetSize(31, 31)
EPI_MinimapButton:SetFrameLevel(8)
EPI_MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
EPI_MinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

local EPI_MinimapOverlay = EPI_MinimapButton:CreateTexture(nil, "OVERLAY")
EPI_MinimapOverlay:SetSize(53, 53)
EPI_MinimapOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
EPI_MinimapOverlay:SetPoint("TOPLEFT")

local EPI_MinimapIcon = EPI_MinimapButton:CreateTexture(nil, "BACKGROUND")
EPI_MinimapButton.icon = EPI_MinimapIcon
EPI_MinimapIcon:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
EPI_MinimapIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
EPI_MinimapIcon:SetSize(20, 20)
EPI_MinimapIcon:SetPoint("CENTER")
EPI_MinimapIcon:SetDesaturated(true)

EPI_MinimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(EPI_SettingsCategory and EPI_SettingsCategory.ID or "EasyPartyInvite")
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(EPI_Options)
        end
    else
        EPI_Addon:Toggle()
    end
end)

EPI_MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("EasyPartyInvite")
    GameTooltip:AddLine("Left-click to toggle auto-invite mode", 1, 1, 1)
    GameTooltip:AddLine("Right-click to open settings", 1, 1, 1)
    GameTooltip:Show()
end)

EPI_MinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Options panel
EPI_Options = CreateFrame("Frame", "EPI_Options")
EPI_Options.name = "EasyPartyInvite"

EPI_EnableCheck = CreateFrame("CheckButton", "EPI_EnableCheck", EPI_Options, "InterfaceOptionsCheckButtonTemplate")
EPI_EnableCheck:SetPoint("TOPLEFT", 16, -16)
EPI_EnableCheck.Text:SetText("Enable auto-invite")
EPI_EnableCheck:SetChecked(EPI_Addon.enabled)
EPI_EnableCheck:SetScript("OnClick", function(self)
    if self:GetChecked() then
        EPI_Addon:Enable()
    else
        EPI_Addon:Disable()
    end
end)

EPI_WhisperCheck = CreateFrame("CheckButton", "EPI_WhisperCheck", EPI_Options, "InterfaceOptionsCheckButtonTemplate")
EPI_WhisperCheck:SetPoint("TOPLEFT", EPI_EnableCheck, "BOTTOMLEFT", 0, -8)
EPI_WhisperCheck.Text:SetText("Enable whisper message")
EPI_WhisperCheck:SetChecked(EPI_Settings.whisperEnabled)

EPI_MessageInput = CreateFrame("EditBox", "EPI_MessageInput", EPI_Options, "InputBoxTemplate")
EPI_MessageInput:SetSize(220, 25)
EPI_MessageInput:SetAutoFocus(false)
EPI_MessageInput:SetPoint("TOPLEFT", EPI_WhisperCheck, "BOTTOMLEFT", 30, -8)
EPI_MessageInput:SetText(EPI_Settings.whisperMessage)
EPI_MessageInput:SetScript("OnEnterPressed", function(self)
    EPI_Settings.whisperMessage = self:GetText()
    self:ClearFocus()
end)
EPI_MessageInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
EPI_MessageInput:SetScript("OnEditFocusLost", function(self)
    EPI_Settings.whisperMessage = self:GetText()
end)

local function EPI_UpdateMessageInput()
    if EPI_WhisperCheck:GetChecked() then
        EPI_MessageInput:Show()
    else
        EPI_MessageInput:Hide()
    end
end

EPI_WhisperCheck:SetScript("OnClick", function(self)
    EPI_Settings.whisperEnabled = self:GetChecked()
    EPI_UpdateMessageInput()
end)

EPI_UpdateMessageInput()
EPI_Options:HookScript("OnShow", function()
    EPI_EnableCheck:SetChecked(EPI_Addon.enabled)
    EPI_WhisperCheck:SetChecked(EPI_Settings.whisperEnabled)
    EPI_MessageInput:SetText(EPI_Settings.whisperMessage)
    EPI_UpdateMessageInput()
end)
if Settings and Settings.RegisterAddOnCategory then
    EPI_SettingsCategory = Settings.RegisterCanvasLayoutCategory(EPI_Options, EPI_Options.name)
    EPI_SettingsCategory.ID = EPI_Options.name
    Settings.RegisterAddOnCategory(EPI_SettingsCategory)
else
    InterfaceOptions_AddCategory(EPI_Options)
end

-- Chat commands
SLASH_EPI1 = "/epi"
SlashCmdList["EPI"] = function(EPI_Command)
    local EPI_Cmd, EPI_Rest = (EPI_Command or ""):match("^(%S*)%s*(.-)$")
    EPI_Cmd = string.lower(EPI_Cmd)
    if EPI_Cmd == "toggle" then
        EPI_Addon:Toggle()
    elseif EPI_Cmd == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Auto-invite is " .. (EPI_Addon.enabled and "enabled" or "disabled") .. ".")
    elseif EPI_Cmd == "message" then
        if EPI_Rest == "" then
            if EPI_Settings.whisperEnabled and EPI_Settings.whisperMessage ~= "" then
                DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Current whisper message: " .. EPI_Settings.whisperMessage)
            else
                DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: No whisper message set.")
            end
        else
            EPI_Settings.whisperMessage = EPI_Rest
            EPI_Settings.whisperEnabled = true
            DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Whisper message set to '" .. EPI_Rest .. "'.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite commands: /epi toggle, /epi status, /epi message <text>")
    end
end

