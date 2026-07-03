local currentDead = nil
local started = false

local function debugPrint(msg)
    if Config.Debug then
        print(('[bc_dead_voice_blocker:client] %s'):format(msg))
    end
end

local function callSaltyExport(exportName, ...)
    if GetResourceState(Config.SaltyResource) ~= 'started' then
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
        debugPrint(('Salty client export failed: %s'):format(exportName))
        return nil, false
    end

    return result, result ~= nil
end

local function stateValueIsTrue(value)
    return value == true or value == 1 or value == 'true' or value == '1'
end

local function hasAnyTrueState(keys)
    local state = LocalPlayer and LocalPlayer.state
    if not state then return false end

    for i = 1, #keys do
        if stateValueIsTrue(state[keys[i]]) then
            return true, keys[i]
        end
    end

    return false, nil
end

local function readDeadState()
    local deadByState, deadKey = hasAnyTrueState(Config.DeadStateKeys)
    if deadByState then return true, deadKey end

    if Config.BlockLaststand then
        local laststandByState, laststandKey = hasAnyTrueState(Config.LaststandStateKeys)
        if laststandByState then return true, laststandKey end
    end

    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        if IsEntityDead(ped) or IsPedFatallyInjured(ped) or GetEntityHealth(ped) <= 0 then
            return true, 'native_ped_dead'
        end
    end

    return false, 'alive'
end

local function getRadioChannels()
    if not Config.RemoveRadioOnDeath then
        return nil, nil
    end

    local primary = callSaltyExport('GetRadioChannel', true)
    local secondary = callSaltyExport('GetRadioChannel', false)

    return primary, secondary
end

local function pushDeadState(dead, reason)
    dead = dead == true

    if currentDead == dead and started then
        return
    end

    started = true
    currentDead = dead

    local primaryRadio, secondaryRadio = getRadioChannels()
    debugPrint(('dead=%s reason=%s primaryRadio=%s secondaryRadio=%s'):format(
        tostring(dead), tostring(reason), tostring(primaryRadio), tostring(secondaryRadio)
    ))

    TriggerServerEvent('bc_dead_voice_blocker:setDeadState', dead, primaryRadio, secondaryRadio, reason)
end

local function refreshDeadState(reason)
    local dead, detectedBy = readDeadState()
    pushDeadState(dead, reason or detectedBy)
end

-- Generic FiveM/baseevents hooks.
AddEventHandler('baseevents:onPlayerDied', function()
    pushDeadState(true, 'baseevents:onPlayerDied')
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    pushDeadState(true, 'baseevents:onPlayerKilled')
end)

AddEventHandler('playerSpawned', function()
    SetTimeout(1000, function()
        refreshDeadState('playerSpawned')
    end)
end)

-- ESX compatibility hooks.
AddEventHandler('esx:onPlayerDeath', function()
    pushDeadState(true, 'esx:onPlayerDeath')
end)

RegisterNetEvent('esx_ambulancejob:revive', function()
    SetTimeout(1000, function()
        refreshDeadState('esx_ambulancejob:revive')
    end)
end)

-- QB/QBOX compatibility hooks. Polling is still the real fallback.
RegisterNetEvent('hospital:client:SetLaststandStatus', function(isLaststand)
    if Config.BlockLaststand then
        pushDeadState(isLaststand == true, 'hospital:client:SetLaststandStatus')
    end
end)

RegisterNetEvent('hospital:client:SetDeathStatus', function(isDead)
    pushDeadState(isDead == true, 'hospital:client:SetDeathStatus')
end)

RegisterNetEvent('hospital:client:Revive', function()
    SetTimeout(1000, function()
        refreshDeadState('hospital:client:Revive')
    end)
end)

RegisterNetEvent('qbx_medical:client:playerRevived', function()
    SetTimeout(1000, function()
        refreshDeadState('qbx_medical:client:playerRevived')
    end)
end)

-- Statebag change handlers for common names.
CreateThread(function()
    local function addHandler(key)
        AddStateBagChangeHandler(key, nil, function(bagName, _, value)
            if bagName ~= ('player:%s'):format(GetPlayerServerId(PlayerId())) then return end

            if stateValueIsTrue(value) then
                pushDeadState(true, ('state:%s'):format(key))
            else
                SetTimeout(250, function()
                    refreshDeadState(('state:%s-cleared'):format(key))
                end)
            end
        end)
    end

    for i = 1, #Config.DeadStateKeys do
        addHandler(Config.DeadStateKeys[i])
    end

    if Config.BlockLaststand then
        for i = 1, #Config.LaststandStateKeys do
            addHandler(Config.LaststandStateKeys[i])
        end
    end
end)

-- Fallback polling catches unknown death resources and resource restart order issues.
CreateThread(function()
    Wait(2000)
    refreshDeadState('startup')

    while true do
        refreshDeadState('poll')
        Wait(Config.PollIntervalMs)
    end
end)

-- Native voice/PTT fallback block.
CreateThread(function()
    while true do
        if Config.DisableNativePushToTalkWhileDead and currentDead then
            DisableControlAction(0, Config.NativePushToTalkControl, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('IsDeadVoiceBlocked', function()
    return currentDead == true
end)
