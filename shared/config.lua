Config = Config or {}

-- Name of your SaltyChat resource.
Config.SaltyResource = 'saltychat'

-- Polling is intentionally kept light. Statebag/event checks are instant; polling is only a fallback.
Config.PollIntervalMs = 750

-- Treat laststand as dead for voice purposes. Recommended for RP servers.
Config.BlockLaststand = true

-- These are common statebag names used by QB/QBOX/medical/death resources.
-- Add your death script's exact state key here if it uses a different one.
Config.DeadStateKeys = {
    'dead',
    'isDead',
    'isdead',
    'wasted',
    'isWasted',
}

Config.LaststandStateKeys = {
    'laststand',
    'inLaststand',
    'inlaststand',
    'isInLaststand',
}

-- Hard block fallback: Set Salty voice range to 0 while dead and restore after revive.
-- This helps on builds where SetPlayerAlive(false) only affects radio but not proximity.
Config.SetVoiceRangeZeroWhileDead = true
Config.DeadVoiceRange = 0.0
Config.FallbackRestoreVoiceRange = 8.0

-- Remove radio channels when the player dies.
Config.RemoveRadioOnDeath = true

-- Also disable FiveM's native PTT control while dead. Salty/TeamSpeak can still be separate,
-- but this prevents fallback in-game voice from leaking.
Config.DisableNativePushToTalkWhileDead = true
Config.NativePushToTalkControl = 249

-- Salty Lua resource exposes these state names in config.lua.
Config.SaltyAliveStateKey = 'SaltyChat_IsAlive'
Config.SaltyVoiceRangeStateKey = 'SaltyChat_VoiceRange'

-- Debug output in server/client console.
Config.Debug = true
