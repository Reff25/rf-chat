Config = {}

-- Local /me visibility radius in meters (server-side check)
Config.MeDistance = 20.0

-- Hard cap for /me action text only (other commands are not truncated)
Config.MaxMessageLength = 150

-- Minimum time between /me uses per player (ms)
Config.CommandCooldown = 400

Config.UI = {
    Position = 'top-left', -- reserved for later layout options
    MaxMessages = 8,
    HideDelay = 7000, -- ms after last message / close before fading out
    SuggestionLimit = 5,
    MaxInputLength = 255,
}

Config.Locale = {
    UnknownCommand = 'Unknown command',
}

Config.OpenKey = 'T' -- RegisterKeyMapping default (players can rebind in GTA settings)
