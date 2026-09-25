local isOpen = false

local function nuiMessage(payload)
    SendNUIMessage(payload)
end

local function uiMeta()
    return {
        hideDelay = Config.UI.HideDelay,
        maxMessages = Config.UI.MaxMessages,
        maxLength = Config.UI.MaxInputLength,
        suggestionLimit = Config.UI.SuggestionLimit,
        position = Config.UI.Position,
    }
end

local function closeChat()
    if not isOpen then
        return
    end

    isOpen = false
    SetNuiFocus(false, false)
    nuiMessage({ action = 'closeInput' })
end

local function openChat()
    if isOpen or IsPauseMenuActive() then
        return
    end

    isOpen = true
    SetNuiFocus(true, true)

    local payload = uiMeta()
    payload.action = 'openInput'
    nuiMessage(payload)

    CreateThread(function()
        while isOpen do
            if IsPauseMenuActive() then
                closeChat()
                break
            end
            Wait(200)
        end
    end)
end

local function addLocalMessage(message)
    local payload = uiMeta()
    payload.action = 'addMessage'
    payload.message = message
    nuiMessage(payload)
end

local function stripDisplay(value)
    value = tostring(value or '')
    value = value:gsub('%^%d', '')
    value = value:gsub('%^#[%x]+', '')
    value = value:gsub('<[^>]+>', '')
    value = value:gsub('[%c]', ' ')
    value = value:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return value
end

local function flattenChatMessage(message)
    if type(message) == 'string' then
        return stripDisplay(message)
    end

    if type(message) ~= 'table' then
        return nil
    end

    if type(message.text) == 'string' and message.text ~= '' then
        return stripDisplay(message.text)
    end

    if type(message.args) == 'table' then
        local parts = {}
        for i = 1, #message.args do
            parts[#parts + 1] = tostring(message.args[i])
        end

        if #parts == 0 then
            return nil
        end

        if #parts == 2 then
            return stripDisplay(parts[1] .. ': ' .. parts[2])
        end

        return stripDisplay(table.concat(parts, ' '))
    end

    return nil
end

local function showCompatMessage(message)
    if type(message) == 'table' and message.type == 'me' and type(message.text) == 'string' then
        addLocalMessage(message)
        return
    end

    local text = flattenChatMessage(message)
    if not text or text == '' then
        return
    end

    addLocalMessage({
        type = 'system',
        text = text,
    })
end

local function hasClientCommand(name)
    if not name or not GetRegisteredCommands then
        return false
    end

    name = name:lower()
    local registered = GetRegisteredCommands()
    for i = 1, #registered do
        local command = registered[i]
        if command and command.name and command.name:lower() == name then
            return true
        end
    end

    return false
end

local function refreshCommands()
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
                if IsAceAllowed(('command.%s'):format(command.name)) then
                    suggestions[#suggestions + 1] = {
                        name = '/' .. command.name,
                        help = '',
                    }
                end
            end
        end
    end

    TriggerEvent('chat:addSuggestions', suggestions)
end

RegisterCommand('rfchat:open', function()
    openChat()
end, false)

RegisterKeyMapping('rfchat:open', 'Open Chat', 'keyboard', Config.OpenKey)

RegisterNUICallback('ready', function(_, cb)
    local payload = uiMeta()
    payload.action = 'setup'
    nuiMessage(payload)

    TriggerServerEvent('chat:init')
    refreshCommands()

    TriggerEvent('chat:addSuggestion', '/me', 'Roleplay an action nearby', {
        { name = 'action', help = 'What your character does' },
    })

    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeChat()
    cb({ ok = true })
end)

RegisterNUICallback('submit', function(data, cb)
    cb({ ok = true })

    local message = data and data.message or ''
    closeChat()

    if type(message) ~= 'string' then
        return
    end

    message = message:gsub('^%s+', ''):gsub('%s+$', '')
    if message == '' then
        return
    end

    -- Plain text is ignored completely: no events, no UI, no network.
    if message:sub(1, 1) ~= '/' then
        return
    end

    if message:sub(2) == '' then
        return
    end

    -- Same path as the original chat resource: hand the raw command string to FiveM.
    ExecuteCommand(message:sub(2))
end)

RegisterNetEvent('rf-chat:client:addMessage', function(message)
    if type(message) ~= 'table' or type(message.text) ~= 'string' then
        return
    end

    addLocalMessage(message)
end)

RegisterNetEvent('rf-chat:client:unknownCommand', function(command)
    local name = tostring(command or ''):match('^(%S+)')
    if name and hasClientCommand(name) then
        return
    end

    addLocalMessage({
        type = 'system',
        text = Config.Locale.UnknownCommand,
    })
end)

-- Original chat API used by other resources (events keep the same names).
RegisterNetEvent('chatMessage')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')
RegisterNetEvent('__cfx_internal:serverPrint')

AddEventHandler('chatMessage', function(author, _, text)
    local args
    if author and author ~= '' then
        args = { author, text }
    else
        args = { text }
    end

    showCompatMessage({ args = args })
end)

AddEventHandler('chat:addMessage', function(message)
    showCompatMessage(message)
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
    showCompatMessage({ args = { msg } })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
    local suggestion

    if type(name) == 'table' then
        suggestion = name
        suggestion.params = suggestion.params or {}
    elseif type(name) == 'string' then
        suggestion = {
            name = name,
            help = help,
            params = params or {},
        }
    else
        return
    end

    nuiMessage({
        action = 'addSuggestion',
        suggestion = suggestion,
    })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
    if type(suggestions) ~= 'table' then
        return
    end

    for _, item in ipairs(suggestions) do
        if item then
            TriggerEvent('chat:addSuggestion', item.name, item.help, item.params)
        end
    end
end)

AddEventHandler('chat:removeSuggestion', function(name)
    nuiMessage({
        action = 'removeSuggestion',
        name = name,
    })
end)

AddEventHandler('chat:clear', function()
    nuiMessage({ action = 'clear' })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTextChatEnabled(false)
        SetNuiFocus(false, false)
    end

    Wait(500)
    refreshCommands()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetTextChatEnabled(true)
        return
    end

    Wait(500)
    refreshCommands()
end)

exports('addMessage', function(message)
    showCompatMessage(message)
end)

exports('addSuggestion', function(name, help, params)
    TriggerEvent('chat:addSuggestion', name, help, params)
end)

exports('removeSuggestion', function(name)
    TriggerEvent('chat:removeSuggestion', name)
end)

exports('clear', function()
    TriggerEvent('chat:clear')
end)
