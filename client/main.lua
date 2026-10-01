--[[
    Entrada do client. Cada parte e um modulo em client/ (carregado pelo
    require do ox_lib); a ordem aqui so garante que todos sobem no start.
]]

require 'client.state'
require 'client.dui'
require 'client.scan'
require 'client.input'
require 'client.render'
require 'client.vehicle'
require 'client.api'
require 'client.compat.ox_target'
require 'client.compat.qb'
require 'client.compat.sleepless_interact'
require 'client.panel'
