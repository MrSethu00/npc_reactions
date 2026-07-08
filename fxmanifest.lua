fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Zone-Based NPC Reactions with Vehicle Chase - ESX Framework'
version '2.0.0'

client_scripts {
    'config.lua',
    'client.lua'
}

server_scripts {
    'config.lua',
    'server.lua'
}

exports {
    'GetPlayerJob',
    'JailPlayer',
    'ReleasePlayer',
    'UpdatePlayerJob'
}

dependencies {
    'es_extended',
    'chat'
}
