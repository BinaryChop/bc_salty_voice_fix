local previousVoiceRange = {}
local currentDead = {}

local function debugPrint(msg)
    if Config.Debug then
        print(('[bc_dead_voice_blocker:server] %s'):format(msg))
    end
end

local function callSaltyExport(exportName, ...)
    if GetResourceState(Config.SaltyResource) ~= 'started' then
        debugPrint(('Salty resource %s not started, skipped %s'):format(Config.SaltyResource, exportName))
        return nil, false
    end

    local args = { ... }
    local ok, result = pcall(function()
        local resourceExports = exports[Config.SaltyResource]
        if not resourceExports or not resourceExports[exportName] then
            return nil
        end
        return resourceExports[exportName](table.unpack(args))
    end)

    if not ok then
        debugPrint(('Salty server export failed: %s'):format(exportName))
        return nil, false
    end

    return result, result ~= nil
end

local function getPlayerState(src)
    local ply = Player(src)
    if not ply then return nil end
    return ply.state
end

local function setSaltyAliveState(src, alive)
    local state = getPlayerState(src)
    if not state then return end

    -- Direct statebag fallback for the Lua resource, whose config exposes this key.
    state:set(Config.SaltyAliveStateKey, alive == true, true)

    -- Official documented server export for the public SaltyChat FiveM implementation.
    -- IMPORTANT: this parameter is isAlive, not isDead.
    callSaltyExport('SetPlayerAlive', src, alive == true)
end

local function rememberVoiceRange(src)
    if previousVoiceRange[src] ~= nil then return end

    local range = callSaltyExport('GetPlayerVoiceRange', src)

    if range == nil then
        local state = getPlayerState(src)
        range = state and state[Config.SaltyVoiceRangeStateKey] or nil
    end

    if type(range) ~= 'number' then
        range = Config.FallbackRestoreVoiceRange
    end

    previousVoiceRange[src] = range
end

local function setVoiceRange(src, range)
    if not Config.SetVoiceRangeZeroWhileDead then return end
    callSaltyExport('SetPlayerVoiceRange', src, tonumber(range) or Config.FallbackRestoreVoiceRange)
end

local function removeRadio(src, primaryRadio, secondaryRadio)
    if not Config.RemoveRadioOnDeath then return end

    local seen = {}
    local channels = { primaryRadio, secondaryRadio }

    for i = 1, #channels do
        local channel = channels[i]
        if channel ~= nil and channel ~= false then
            channel = tostring(channel)
            if channel ~= '' and not seen[channel] then
                seen[channel] = true
                callSaltyExport('RemovePlayerRadioChannel', src, channel)
            end
        end
    end
end

local function applyDeadState(src, dead, primaryRadio, secondaryRadio, reason)
    src = tonumber(src)
    if not src or src <= 0 then return end

    dead = dead == true

    if currentDead[src] == dead then
        return
    end

    currentDead[src] = dead
    debugPrint(('src=%s dead=%s reason=%s'):format(src, tostring(dead), tostring(reason)))

    if dead then
        rememberVoiceRange(src)
        setSaltyAliveState(src, false)
        setVoiceRange(src, Config.DeadVoiceRange)
        removeRadio(src, primaryRadio, secondaryRadio)
    else
        setSaltyAliveState(src, true)
        setVoiceRange(src, previousVoiceRange[src] or Config.FallbackRestoreVoiceRange)
        previousVoiceRange[src] = nil
    end
end

RegisterNetEvent('bc_dead_voice_blocker:setDeadState', function(dead, primaryRadio, secondaryRadio, reason)
    applyDeadState(source, dead, primaryRadio, secondaryRadio, reason)
end)

exports('SetDeadState', function(src, dead)
    applyDeadState(src, dead, nil, nil, 'external_export')
end)

exports('IsDeadVoiceBlocked', function(src)
    return currentDead[tonumber(src)] == true
end)

AddEventHandler('playerDropped', function()
    local src = source
    previousVoiceRange[src] = nil
    currentDead[src] = nil
end)
