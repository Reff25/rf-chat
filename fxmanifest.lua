fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rf-chat'
author 'rf-chat'
description 'QBCore command-based RP chat'
version '1.1.0'

-- Lets other resources that depend on `chat` keep working while this resource is the UI.
provide 'chat'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'qb-core'
