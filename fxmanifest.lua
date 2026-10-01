fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'mri_Qinteract'
author 'MRI Qbox Brasil'
version '1.0.0'
description 'AAA-Grade Interaction Experience for FiveM'

ox_lib 'locale'

-- Painel /admininteract (tambem embutido no mri_Qadmin). O prompt no mundo e
-- uma DUI separada (web/build/index.html).
ui_page 'web/build/admin.html'

shared_scripts {
	'@ox_lib/init.lua',
}

client_scripts {
	'client/main.lua',
}

server_scripts {
	'server/main.lua',
}

files {
	'locales/*.json',
	'web/build/**',
	'web/markers/*.png',
	'client/**/*.lua',
	'shared/*.lua',
	'data/*.json',
}

provides {
	'ox_target',
	'qtarget',
	'qb-target',
	'sleepless_interact',
}

dependency 'ox_lib'
