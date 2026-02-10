--[[----------------------------------------------------------------------------

    FloatingInterruptHighlight
    FloatingInterruptHighlight.lua — Frame behavior, cast detection, glow,
                                      drag, visibility

----------------------------------------------------------------------------]]--

local addonName, addon = ...

local ACR = LibStub("AceConfigRegistry-3.0")
local Masque = LibStub("Masque", true)

local C_Spell = C_Spell
local GetTime = GetTime

local frameStrata = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "TOOLTIP",
}

local REACTION_TIME = 0.2

--[[------------------------------------------------------------------------]]--
--  Interrupt Spell Table (from ActionBarInterruptHighlight/Controller.lua)
--[[------------------------------------------------------------------------]]--

-- spellID → base cooldown in seconds
local InterruptSpells = {
    [ 47528] = 15,      -- Mind Freeze (Death Knight)
    [183752] = 15,      -- Disrupt (Demon Hunter)
    [ 78675] = 60,      -- Solar Beam (Druid)
    [106839] = 15,      -- Skull Bash (Druid)
    [147362] = 24,      -- Counter Shot (Hunter)
    [187707] = 15,      -- Muzzle (Hunter)
    [  2139] = 24,      -- Counterspell (Mage)
    [116705] = 15,      -- Spear Hand Strike (Monk)
    [ 96231] = 15,      -- Rebuke (Paladin)
    [ 15487] = 45,      -- Silence (Priest)
    [  1766] = 15,      -- Kick (Rogue)
    [ 57994] = 12,      -- Wind Shear (Shaman)
    [ 19647] = 24,      -- Spell Lock (Warlock Felhunter Pet)
    [119910] = 24,      -- Spell Lock (Warlock Command Demon)
    [132409] = 24,      -- Spell Lock (Warlock Grimoire of Sacrifice)
    [ 89766] = 30,      -- Axe Toss (Warlock Felguard Pet)
    [119914] = 30,      -- Axe Toss (Warlock Command Demon)
    [  6552] = 15,      -- Pummel (Warrior)
    [351338] = 20,      -- Quell (Evoker)
}

-- Ordered list for detection (first known wins)
local InterruptSpellIDs = {
     47528, 183752,  78675, 106839, 147362, 187707,
      2139, 116705,  96231,  15487,   1766,  57994,
     19647, 119910, 132409,  89766, 119914,   6552, 351338,
}

--[[------------------------------------------------------------------------]]--
--  Timer Color Curve (from ActionBarInterruptHighlight/Overlay.lua)
--[[------------------------------------------------------------------------]]--

local timerColorCurve = C_CurveUtil.CreateColorCurve()
timerColorCurve:SetType(Enum.LuaCurveType.Linear)
timerColorCurve:AddPoint(0.0,  CreateColor(1, 0.5, 0.5, 1))
timerColorCurve:AddPoint(3.0,  CreateColor(1, 1,   0.5, 1))
timerColorCurve:AddPoint(3.01, CreateColor(1, 1,   1,   1))
timerColorCurve:AddPoint(10.0, CreateColor(1, 1,   1,   1))

--[[------------------------------------------------------------------------]]--
--  FIHGlowMixin — Glow overlay behavior
--  (Adapted from ActionBarInterruptHighlight/Overlay.lua)
--[[------------------------------------------------------------------------]]--

FIHGlowMixin = {}

function FIHGlowMixin:OnHide()
    self:StopAnim()
    self:StopTimer()
end

function FIHGlowMixin:OnUpdate()
    if self.duration then
        local color = self.duration:EvaluateRemainingDuration(timerColorCurve)
        self.Timer:SetFormattedText("%0.1f", self.duration:GetRemainingDuration())
        self.Timer:SetTextColor(color:GetRGB())
    else
        self:StopTimer()
    end
end

function FIHGlowMixin:StopAnim()
    if self.ProcLoop:IsPlaying() then
        self.ProcLoop:Stop()
    end
end

function FIHGlowMixin:StartAnim()
    self.ProcLoop:Play()
end

function FIHGlowMixin:StartTimer(duration)
    self.duration = duration
    self.Timer:Show()
    self:SetScript("OnUpdate", self.OnUpdate)
end

function FIHGlowMixin:StopTimer()
    self.duration = nil
    self.Timer:Hide()
    self:SetScript("OnUpdate", nil)
end

-- Because notInterruptible is a secret, we can no longer show/hide
-- as a result of it, best we can do is SetAlphaFromBoolean. So
-- the animation and timer are always "playing" if there's a spell
-- cast going on, and we only make them visible with alpha if the
-- cast is interruptible.

function FIHGlowMixin:Update(active, notInterruptible, duration)
    if active then
        self:StartAnim()
        self:StartTimer(duration)
        self:SetAlphaFromBoolean(notInterruptible, 0, 1)
        self:Show()
    else
        self:Hide()
    end
end

--[[------------------------------------------------------------------------]]--
--  FIHFrameMixin — Main frame behavior
--[[------------------------------------------------------------------------]]--

local function HideLikelyMasqueRegions(frame)
    if not Masque then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if not frame.__baselineRegions[region] then
            region:Hide()
        end
    end
end

FIHFrameMixin = {}

function FIHFrameMixin:OnLoad()
    self.interruptSpellID = nil
    self.interruptCdStart = 0
    self.interruptCdDuration = 0

    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterForDrag("LeftButton")

    if Masque then
        self:SetBackdrop({ edgeSize = 0 })

        local set = {}
        for _, r in ipairs({ self:GetRegions() }) do
            set[r] = true
        end
        self.__baselineRegions = set

        self.MSQGroup = Masque:Group(C_AddOns.GetAddOnMetadata(addonName, "Title"))
        Masque:AddType("FIH", { "Icon", "Cooldown" })
        self.MSQGroup:AddButton(self, {
            Icon = self.Icon,
            Cooldown = self.Cooldown,
        }, "FIH")

        self.MSQGroup:RegisterCallback(function(_, Option, Value)
            if Option == "Disabled" and Value == true then
                HideLikelyMasqueRegions(self)
            end
            self:ApplyOptions()
        end)
    end
end

function FIHFrameMixin:OnAddonLoaded()
    self.db = addon.db.profile
end

function FIHFrameMixin:Initialize()
    -- Cast tracking events
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")

    -- Spell detection events
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("UNIT_PET")

    -- Cooldown event
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    -- Track interrupt usage (cooldown is secret, so we record GetTime + base duration)
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    self:DetectInterruptSpell()
    self:ApplyOptions()
end

--[[------------------------------------------------------------------------]]--
--  Interrupt Spell Detection
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:DetectInterruptSpell()
    self.interruptSpellID = nil
    self.interruptCdStart = 0
    self.interruptCdDuration = 0

    for _, spellID in ipairs(InterruptSpellIDs) do
        if C_SpellBook.IsSpellInSpellBook(spellID) then
            self.interruptSpellID = spellID
            break
        end
    end

    if self.interruptSpellID then
        local texture = C_Spell.GetSpellTexture(self.interruptSpellID)
        if texture then
            self.Icon:SetTexture(texture)
        end
    end

    self:UpdateVisibility()
end

--[[------------------------------------------------------------------------]]--
--  Interrupt Cooldown Tracking
--
--  The actual cooldown of interrupt spells is secret (C_Spell.GetSpellCooldown
--  only reports the GCD).  We track usage ourselves via UNIT_SPELLCAST_SUCCEEDED
--  and apply the base cooldown duration from our lookup table.
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:OnInterruptUsed(spellID)
    local baseCd = InterruptSpells[spellID]
    if not baseCd then return end
    self.interruptCdStart = GetTime()
    self.interruptCdDuration = baseCd
end

function FIHFrameMixin:GetInterruptCooldownRemaining()
    if self.interruptCdDuration == 0 then return 0 end
    local remaining = (self.interruptCdStart + self.interruptCdDuration) - GetTime()
    if remaining <= 0 then
        self.interruptCdDuration = 0
        return 0
    end
    return remaining
end

-- Returns true if the interrupt is off cooldown.
-- Note: duration:GetRemainingDuration() is a secret value and cannot
-- be compared, so we can only check whether the interrupt is currently ready.
function FIHFrameMixin:CanInterrupt()
    return self:GetInterruptCooldownRemaining() <= REACTION_TIME
end

function FIHFrameMixin:ScheduleCooldownRecheck()
    self:CancelCooldownRecheck()
    local remaining = self:GetInterruptCooldownRemaining() - REACTION_TIME
    if remaining > 0 then
        self.cdRecheckTimer = C_Timer.NewTimer(remaining, function()
            self.cdRecheckTimer = nil
            self:UpdateCastState()
            self:UpdateCooldown()
        end)
    end
end

function FIHFrameMixin:CancelCooldownRecheck()
    if self.cdRecheckTimer then
        self.cdRecheckTimer:Cancel()
        self.cdRecheckTimer = nil
    end
end

--[[------------------------------------------------------------------------]]--
--  Cast State Detection (from Controller.lua:120-138)
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:UpdateCastState()
    self:CancelCooldownRecheck()

    if not self.interruptSpellID then
        self.GlowOverlay:Update(false)
        return
    end

    local name, notInterruptible, _

    name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
    if name then
        local duration = UnitCastingDuration("target")
        if duration then
            if self:CanInterrupt() then
                self:ShowForCast(notInterruptible)
                self.GlowOverlay:Update(true, notInterruptible, duration)
            else
                self:HideForCast()
                self.GlowOverlay:Update(false)
                self:ScheduleCooldownRecheck()
            end
        else
            self:HideForCast()
            self.GlowOverlay:Update(false)
        end
        return
    end

    name, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
    if name then
        local duration = UnitChannelDuration("target")
        if duration then
            if self:CanInterrupt() then
                self:ShowForCast(notInterruptible)
                self.GlowOverlay:Update(true, notInterruptible, duration)
            else
                self:HideForCast()
                self.GlowOverlay:Update(false)
                self:ScheduleCooldownRecheck()
            end
        else
            self:HideForCast()
            self.GlowOverlay:Update(false)
        end
        return
    end

    self:HideForCast()
    self.GlowOverlay:Update(false)
end

--[[------------------------------------------------------------------------]]--
--  Cooldown
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:UpdateCooldown()
    if not self.interruptSpellID or not self:IsShown() then return end

    -- C_Spell.GetSpellCooldown() returns secret values for interrupt spells
    -- so use our manually tracked cooldown instead.
    if self.db.cooldown.showSwipe and self.interruptCdDuration > 0 then
        local remaining = (self.interruptCdStart + self.interruptCdDuration) - GetTime()
        if remaining > 0 then
            self.Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
            self.Cooldown:SetCooldown(self.interruptCdStart, self.interruptCdDuration)
            return
        end
    end

    self.Cooldown:Clear()
end

--[[------------------------------------------------------------------------]]--
--  Visibility
--
--  Unlocked: always visible (so user can position the frame)
--  Locked:   only visible when target is casting an interruptible spell
--            (uses SetAlphaFromBoolean for the notInterruptible secret)
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:ShowForCast(notInterruptible)
    if not self.db.locked then return end
    self:SetShown(true)
    self:SetAlphaFromBoolean(notInterruptible, 0, self.db.alpha)
end

function FIHFrameMixin:HideForCast()
    if not self.db.locked then return end
    self:SetShown(false)
end

function FIHFrameMixin:UpdateVisibility()
    local db = self.db

    if not db.enabled or not self.interruptSpellID then
        self:SetShown(false)
        return
    end

    if not db.locked then
        self:SetAlpha(db.alpha)
        self:SetShown(true)
        return
    end

    -- When locked, visibility is driven by UpdateCastState
    self:UpdateCastState()
end

--[[------------------------------------------------------------------------]]--
--  Dragging (from CombatAssistIcon.lua:675-698)
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:OnDragStart()
    if self.db.locked then return end
    self:StartMoving()
end

function FIHFrameMixin:OnDragStop()
    self:StopMovingOrSizing()

    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    local position = self.db.position
    local strata = position.strata

    self.db.position = {
        strata = strata,
        point = point,
        parent = "UIParent",
        relativePoint = relativePoint,
        X = math.floor(xOfs + 0.5),
        Y = math.floor(yOfs + 0.5),
    }

    ACR:NotifyChange(addonName)
end

--[[------------------------------------------------------------------------]]--
--  Lock / Unlock
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:Lock(locked)
    self:EnableMouse(not locked)
    self:UpdateVisibility()
end

--[[------------------------------------------------------------------------]]--
--  Apply Options
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:ApplyOptions()
    local db = self.db
    local size = db.iconSize

    self:Lock(db.locked)
    self:SetSize(size, size)
    self:SetAlpha(db.alpha)

    -- Glow overlay sizing
    self.GlowOverlay.ProcLoopFlipbook:SetSize(size * 1.4, size * 1.4)

    -- Position
    local parent = _G[db.position.parent] or UIParent
    self:SetParent(parent)
    self:ClearAllPoints()
    self:SetScale(UIParent:GetEffectiveScale() / parent:GetEffectiveScale())
    self:SetPoint(db.position.point, db.position.parent, db.position.relativePoint, db.position.X, db.position.Y)

    self:SetFrameStrata(frameStrata[db.position.strata])
    self:Raise()

    -- Cooldown frame
    self.Cooldown:SetDrawEdge(db.cooldown.edge)
    self.Cooldown:SetDrawBling(db.cooldown.bling)
    self.Cooldown:SetHideCountdownNumbers(db.cooldown.HideNumbers)
    self.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
    self.Cooldown:SetSwipeColor(0, 0, 0)

    -- Border / Masque
    if (not Masque) or (self.MSQGroup and self.MSQGroup.db.Disabled) then
        local border = db.border
        self.Icon:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Icon:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)
        self.Icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

        self.Cooldown:ClearAllPoints()
        self.Cooldown:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Cooldown:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)

        self:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = border.thickness,
        })
        self:SetBackdropBorderColor(border.color.r, border.color.g, border.color.b, border.show and 1 or 0)
    else
        self:ClearBackdrop()
        self.Icon:ClearAllPoints()
        self.Icon:SetAllPoints()
        self.MSQGroup:ReSkin()
    end

    self:UpdateVisibility()
    self:UpdateCooldown()
end

--[[------------------------------------------------------------------------]]--
--  Start / Stop / Reload
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:Start()
    self:DetectInterruptSpell()
    self:ApplyOptions()
end

function FIHFrameMixin:Stop()
    self:SetShown(false)
end

function FIHFrameMixin:Reload()
    self:Stop()
    self.db = addon.db.profile
    self:Start()
end

--[[------------------------------------------------------------------------]]--
--  Event Handler
--[[------------------------------------------------------------------------]]--

function FIHFrameMixin:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:Initialize()

    -- Spell detection
    elseif event == "SPELLS_CHANGED" then
        self:DetectInterruptSpell()
        self:UpdateCastState()
        self:UpdateCooldown()

    elseif event == "UNIT_PET" then
        local unit = ...
        if unit == "player" then
            self:DetectInterruptSpell()
            self:UpdateCastState()
        end

    -- Interrupt used by player — record usage time + base cooldown
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if (unit == "player" or unit == "pet") and InterruptSpells[spellID] then
            self:OnInterruptUsed(spellID)
            self:UpdateCastState()
        end

    -- Cooldown swipe + re-evaluate cast state (cd may have expired)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        self:UpdateCooldown()
        self:UpdateCastState()

    -- Cast tracking
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:UpdateCastState()

    elseif event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
    then
        local unit = ...
        if unit == "target" then
            self:UpdateCastState()
        end
    end
end
