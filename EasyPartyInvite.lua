-- EasyPartyInvite main addon file
-- Handles minimap button, combat log scanning, popup confirmation, and chat commands

local EPI_AddonName, EPI_Addon = ...
EasyPartyInvite = EPI_Addon

local EPI_Frame = CreateFrame("Frame")
EPI_Addon.frame = EPI_Frame

EPI_Addon.invited = {}
EPI_Addon.ignored = {}
EPI_Addon.enabled = false
local EPI_PendingInvite = nil
local EPI_PlayerName, EPI_PlayerRealm = UnitName("player")
local EPI_PlayerFullName = EPI_PlayerRealm and EPI_PlayerRealm ~= "" and EPI_PlayerName .. "-" .. EPI_PlayerRealm or EPI_PlayerName

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
    end
end

function EPI_Addon:Disable()
    if self.enabled then
        self.enabled = false
        EPI_Frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        if self.minimapButton and self.minimapButton.icon then
            self.minimapButton.icon:SetDesaturated(true)
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

EPI_MinimapButton:SetScript("OnClick", function()
    EPI_Addon:Toggle()
end)

EPI_MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("EasyPartyInvite")
    GameTooltip:AddLine("Click to toggle auto-invite mode", 1, 1, 1)
    GameTooltip:Show()
end)

EPI_MinimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Chat commands
SLASH_EPI1 = "/epi"
SlashCmdList["EPI"] = function(EPI_Command)
    EPI_Command = string.lower(EPI_Command or "")
    if EPI_Command == "toggle" then
        EPI_Addon:Toggle()
    elseif EPI_Command == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite: Auto-invite is " .. (EPI_Addon.enabled and "enabled" or "disabled") .. ".")
    else
        DEFAULT_CHAT_FRAME:AddMessage("EasyPartyInvite commands: /epi toggle, /epi status")
    end
end

