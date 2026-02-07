--[[----------------------------------------------------------------------------

    FloatingInterruptHighlight
    Core.lua — AceAddon init, options panel, slash commands

----------------------------------------------------------------------------]]--

local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local Masque = LibStub("Masque", true)

local function IsMasqueActive()
    return Masque and FIHFrame.MSQGroup and not FIHFrame.MSQGroup.db.Disabled
end

addon = AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        enabled = true,
        locked = false,
        iconSize = 48,
        alpha = 1,
        cooldown = {
            showSwipe = true,
            edge = true,
            bling = true,
            HideNumbers = false,
        },
        border = {
            show = true,
            thickness = 2,
            color = { r = 0, g = 0, b = 0 },
        },
        position = {
            strata = 3,
            parent = "UIParent",
            point = "CENTER",
            relativePoint = "CENTER",
            X = 0,
            Y = 0,
        },
    },
}

function addon:OnInitialize()
    self.db = AceDB:New("FloatingInterruptHighlightDB", defaults, true)
    FIHFrame:OnAddonLoaded()

    self.db.RegisterCallback(self, "OnNewProfile", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    self:SetupOptions()
end

function addon:SetupOptions()
    local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
    profileOptions.inline = false
    profileOptions.order = 9

    local generalOptions = {
        type = "group",
        name = "General Settings",
        inline = true,
        args = {
            enabled = {
                type = "toggle",
                name = "Enabled",
                desc = "Enable / Disable the Icon",
                get = function() return addon.db.profile.enabled end,
                set = function(_, val)
                    addon.db.profile.enabled = val
                    if val then
                        FIHFrame:Start()
                    else
                        FIHFrame:Stop()
                    end
                end,
                order = 1,
                width = 0.6,
            },
            locked = {
                type = "toggle",
                name = "Lock Frame",
                desc = "Lock or unlock the frame for movement.\n\nWhen unlocked the icon is always visible.\nWhen locked the icon only appears during interruptible casts.",
                get = function() return addon.db.profile.locked end,
                set = function(_, val)
                    addon.db.profile.locked = val
                    FIHFrame:ApplyOptions()
                end,
                order = 2,
                width = 0.6,
            },
            showCooldownSwipe = {
                type = "toggle",
                name = "Enable Cooldown",
                desc = "Enable or disable the cooldown swipe animation.",
                get = function() return addon.db.profile.cooldown.showSwipe end,
                set = function(_, val)
                    addon.db.profile.cooldown.showSwipe = val
                    FIHFrame:ApplyOptions()
                end,
                order = 3,
                width = 0.8,
            },
        },
    }

    local displayOptions = {
        type = "group",
        name = "Display",
        inline = false,
        order = 1,
        args = {
            grp3 = {
                type = "group",
                name = "Icon",
                inline = true,
                order = 3,
                args = {
                    iconSize = {
                        type = "range",
                        name = "Size",
                        desc = "Set the size of the icon",
                        min = 20, max = 300, step = 1,
                        get = function() return addon.db.profile.iconSize end,
                        set = function(_, val)
                            addon.db.profile.iconSize = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 2,
                        width = "normal",
                    },
                    alpha = {
                        type = "range",
                        name = " Alpha",
                        desc = "Change the alpha of the icon",
                        min = 0, max = 1, step = 0.01,
                        get = function() return addon.db.profile.alpha end,
                        set = function(_, val)
                            addon.db.profile.alpha = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 3,
                        width = "normal",
                    },
                },
            },
            grp4 = {
                type = "group",
                name = "Border",
                inline = true,
                order = 4,
                args = {
                    masqueWarning = {
                        type = "description",
                        name = "|cffffa000Border is currently overridden by Masque.|r",
                        hidden = function() return not IsMasqueActive() end,
                        order = 0,
                    },
                    borderColor = {
                        type = "color",
                        name = "Color",
                        desc = "Change the color of the border",
                        hasAlpha = false,
                        get = function()
                            local c = addon.db.profile.border.color
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b)
                            addon.db.profile.border.color = { r = r, g = g, b = b }
                            FIHFrame:ApplyOptions()
                        end,
                        hidden = function() return IsMasqueActive() end,
                        order = 2,
                    },
                    borderThickness = {
                        type = "range",
                        name = " Thickness",
                        desc = "Change the thickness of the icon border",
                        min = 0, max = 10, step = 1,
                        get = function() return addon.db.profile.border.thickness end,
                        set = function(_, val)
                            addon.db.profile.border.thickness = val
                            FIHFrame:ApplyOptions()
                        end,
                        hidden = function() return IsMasqueActive() end,
                        order = 1,
                    },
                },
            },
        },
    }

    local cooldownOptions = {
        type = "group",
        name = "Cooldown",
        inline = false,
        order = 3,
        args = {
            subgroup1 = {
                type = "group",
                name = "Cooldown",
                inline = true,
                args = {
                    edge = {
                        type = "toggle",
                        name = "Draw Edge",
                        desc = "Sets whether a bright line should be drawn on the moving edge of the cooldown animation.",
                        get = function() return addon.db.profile.cooldown.edge end,
                        set = function(_, val)
                            addon.db.profile.cooldown.edge = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 1,
                        width = 0.6,
                    },
                    bling = {
                        type = "toggle",
                        name = "Draw Bling",
                        desc = "Set whether a 'bling' animation plays at the end of a cooldown.",
                        get = function() return addon.db.profile.cooldown.bling end,
                        set = function(_, val)
                            addon.db.profile.cooldown.bling = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 2,
                        width = 0.6,
                    },
                    hideNum = {
                        type = "toggle",
                        name = "Hide Cooldown Numbers",
                        desc = "Hide cooldown number text",
                        get = function() return addon.db.profile.cooldown.HideNumbers end,
                        set = function(_, val)
                            addon.db.profile.cooldown.HideNumbers = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 3,
                        width = 1.1,
                    },
                },
            },
        },
    }

    local positionOptions = {
        type = "group",
        name = "Position",
        inline = false,
        order = 2,
        args = {
            positionGroup = {
                type = "group",
                name = "Position",
                inline = true,
                order = 2,
                args = {
                    point = {
                        type = "select",
                        name = "Relative Anchor Point",
                        desc = "What point on the Screen or parent frame to anchor to.",
                        values = function()
                            return {
                                ["TOPLEFT"] =       "TOPLEFT",
                                ["TOP"] =           "TOP",
                                ["TOPRIGHT"] =      "TOPRIGHT",
                                ["LEFT"] =          "LEFT",
                                ["CENTER"] =        "CENTER",
                                ["RIGHT"] =         "RIGHT",
                                ["BOTTOMLEFT"] =    "BOTTOMLEFT",
                                ["BOTTOM"] =        "BOTTOM",
                                ["BOTTOMRIGHT"] =   "BOTTOMRIGHT",
                            }
                        end,
                        get = function() return addon.db.profile.position.relativePoint end,
                        set = function(_, val)
                            addon.db.profile.position.relativePoint = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 1,
                        width = 0.8,
                    },
                    posX = {
                        type = "range",
                        name = "X",
                        desc = "Set the X offset from the selected Anchor",
                        min = -500, max = 500, step = 1,
                        get = function() return math.floor(addon.db.profile.position.X + 0.5) end,
                        set = function(_, val)
                            addon.db.profile.position.X = math.floor(val + 0.5)
                            FIHFrame:ApplyOptions()
                        end,
                        order = 6,
                        width = 0.8,
                    },
                    posY = {
                        type = "range",
                        name = "Y",
                        desc = "Set the Y offset from the selected Anchor",
                        min = -500, max = 500, step = 1,
                        get = function() return math.floor(addon.db.profile.position.Y + 0.5) end,
                        set = function(_, val)
                            addon.db.profile.position.Y = math.floor(val + 0.5)
                            FIHFrame:ApplyOptions()
                        end,
                        order = 7,
                        width = 0.8,
                    },
                },
            },
            group1 = {
                type = "group",
                name = "Display",
                inline = true,
                order = 1,
                args = {
                    strata = {
                        type = "select",
                        name = "Frame Strata",
                        desc = "Choose the Strata level to render on",
                        values = function()
                            return {
                                "BACKGROUND",
                                "LOW",
                                "MEDIUM",
                                "HIGH",
                                "DIALOG",
                                "TOOLTIP",
                            }
                        end,
                        get = function() return addon.db.profile.position.strata end,
                        set = function(_, val)
                            addon.db.profile.position.strata = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 1,
                        width = 0.8,
                    },
                },
            },
            subgroup2 = {
                type = "group",
                name = "Advanced",
                inline = true,
                args = {
                    parent = {
                        type = "input",
                        name = " Frame Parent",
                        desc = "Enter a frame name to anchor the icon to.",
                        get = function() return addon.db.profile.position.parent or "UIParent" end,
                        set = function(_, val)
                            if val == "" then val = "UIParent" end
                            addon.db.profile.position.parent = val
                            FIHFrame:ApplyOptions()
                        end,
                        validate = function(_, value)
                            if value == "" then return true end
                            if not _G[value] then
                                return "That frame doesn't exist."
                            end
                            return true
                        end,
                        order = 1,
                    },
                    point = {
                        type = "select",
                        name = "Icon Anchor Point",
                        desc = "What point on the Icon should it be anchored by",
                        values = function()
                            return {
                                ["TOPLEFT"] = "TOPLEFT",
                                ["TOP"] = "TOP",
                                ["TOPRIGHT"] = "TOPRIGHT",
                                ["LEFT"] = "LEFT",
                                ["CENTER"] = "CENTER",
                                ["RIGHT"] = "RIGHT",
                                ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                ["BOTTOM"] = "BOTTOM",
                                ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                            }
                        end,
                        get = function() return addon.db.profile.position.point end,
                        set = function(_, val)
                            addon.db.profile.position.point = val
                            FIHFrame:ApplyOptions()
                        end,
                        order = 2,
                        width = 0.8,
                    },
                    warning = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 3,
                        args = {
                            parentWarning = {
                                type = "description",
                                name = "|cffffa000Dragging the icon will reset the Frame Parent back to the UIParent.|r",
                            },
                        },
                    },
                },
            },
        },
    }

    local options = {
        type = "group",
        name = addonTitle,
        args = {
            general = generalOptions,
            display = displayOptions,
            position = positionOptions,
            cooldown = cooldownOptions,
            profiles = profileOptions,
        },
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, addonTitle)

    self:RegisterChatCommand("fih", "SlashCommand")

    AddonCompartmentFrame:RegisterAddon({
        text = addonTitle,
        icon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
        func = function() AceConfigDialog:Open(addonName) end,
    })
end

function addon:OnProfileChanged()
    FIHFrame:Reload()
end

function addon:SlashCommand(input)
    input = input:lower():trim()
    local PREFIX = "|cff4cc9f0FIH|r: "

    if input == "" then
        AceConfigDialog:Open(addonName)
    elseif input == "lock" then
        self.db.profile.locked = not self.db.profile.locked
        FIHFrame:Lock(self.db.profile.locked)
        DEFAULT_CHAT_FRAME:AddMessage(
            PREFIX .. (self.db.profile.locked and "Locked" or "Unlocked")
        )
    elseif input == "unlock" then
        self.db.profile.locked = false
        FIHFrame:Lock(false)
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Unlocked")
    elseif input == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        if self.db.profile.enabled then
            FIHFrame:Start()
        else
            FIHFrame:Stop()
        end
        DEFAULT_CHAT_FRAME:AddMessage(
            PREFIX .. (self.db.profile.enabled and "Enabled" or "Disabled")
        )
    elseif input == "reload" then
        FIHFrame:Reload()
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "Reloaded!")
    else
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX ..
            "Usage:\n" ..
            "/fih          - Open Config Menu\n" ..
            "/fih lock     - Toggle Locking the Icon\n" ..
            "/fih unlock   - Unlock the Icon\n" ..
            "/fih reload   - Restart the addon\n" ..
            "/fih toggle   - Toggle the addon On or Off"
        )
    end
end
