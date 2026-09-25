local QBCore = exports['qb-core']:GetCoreObject()
local lastMeAt = {}

local function trim(value)
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function sanitizeMessage(value)
    if type(value) ~= 'string' then
        return ''
    end

    value = value:gsub('[\r\n\t]', ' ')
    value = value:gsub('%^%d', '')
    value = value:gsub('%^#[%x]+', '')
    value = value:gsub('%s+', ' ')
    value = trim(value)

    if #value > Config.MaxMessageLength then
        value = value:sub(1, Config.MaxMessageLength)
    end

    return value
end

local function getCharacterName(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.charinfo then
        return nil
    end

    local info = player.PlayerData.charinfo
    local firstname = info.firstname and tostring(info.firstname) or ''
    local lastname = info.lastname and tostring(info.lastname) or ''
    local full = trim(firstname .. ' ' .. lastname)

    if full == '' then
        return nil
    end

    return full
end

local function getNearbyPlayers(origin, maxDistance)
    local nearby = {}
    local players = GetPlayers()

    for i = 1, #players do
        local target = tonumber(players[i])
        if target then
            local ped = GetPlayerPed(target)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                if #(origin - coords) <= maxDistance then
                    nearby[#nearby + 1] = target
                end
            end
        end
    end

    return nearby
end

local function refreshCommands(player)
    if not GetRegisteredCommands then
        return
    end

    local suggestions = {}
    local registered = GetRegisteredCommands()

    for i = 1, #registered do
        local command = registered[i]
        if command and command.name then
            local first = command.name:sub(1, 1)
            if first ~= '+' and first ~= '-' then
                if IsPlayerAceAllowed(player, ('command.%s'):format(command.name)) then
                    suggestions[#suggestions + 1] = {
                        name = '/' .. command.name,
                        help = '',
                    }
                end
            end
        end
    end

    TriggerClientEvent('chat:addSuggestions', player, suggestions)
end

-- /me is registered on the server so proximity and names are never client-trusted.
RegisterCommand('me', function(src, args)
    if not src or src == 0 then
        return
    end

    local action = sanitizeMessage(table.concat(args, ' '))
    if action == '' then
        return
    end

    local now = GetGameTimer()
    if lastMeAt[src] and (now - lastMeAt[src]) < Config.CommandCooldown then
        return
    end
    lastMeAt[src] = now

    local name = getCharacterName(src)
    if not name then
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return
    end

    local origin = GetEntityCoords(ped)
    local recipients = getNearbyPlayers(origin, Config.MeDistance)
    local text = ('%s %s'):format(name, action)

    for i = 1, #recipients do
        TriggerClientEvent('rf-chat:client:addMessage', recipients[i], {
            type = 'me',
            name = name,
            action = action,
            text = text,
        })
    end
end, false)

-- Fired by FiveM when ExecuteCommand cannot find a server command.
AddEventHandler('__cfx_internal:commandFallback', function(command)
    local src = source
    if src and src > 0 then
        TriggerClientEvent('rf-chat:client:unknownCommand', src, command)
    end

    CancelEvent()
end)

RegisterNetEvent('chat:init', function()
    refreshCommands(source)
end)

AddEventHandler('onServerResourceStart', function()
    Wait(500)

    local players = GetPlayers()
    for i = 1, #players do
        refreshCommands(players[i])
    end
end)

AddEventHandler('playerDropped', function()
    lastMeAt[source] = nil
end)
