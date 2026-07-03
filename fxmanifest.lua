fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'BinaryChop'
description 'Blocks SaltyChat voice/radio while player is dead or in laststand/wasted state.'
version '1.0.1'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

dependency 'saltychat'