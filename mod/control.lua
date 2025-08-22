local prometheus = require("lib/prometheus")

local registry = prometheus.Registry.new("factorio_")

local gauge_players_connected = registry:new_gauge("players_connected", "Players connected")
local gauge_players_total = registry:new_gauge("players_total", "Players total")

local counter_player_deaths = registry:new_counter("player_deaths", "Player deaths")

local function on_player_change(event)
    gauge_players_connected:set(#game.connected_players)
    gauge_players_total:set(#game.players)
end

local function on_player_died(event)
    counter_player_deaths:increment(1)
end

local function collect_metrics()
    -- helpers.write_file("statorio/game.prom", registry:collect_metrics(), false, 0)
    helpers.write_file("statorio/game.prom", registry:collect_metrics(), false)
end

local function init()
    script.on_event(defines.events.on_player_joined_game, on_player_change)
    script.on_event(defines.events.on_player_left_game, on_player_change)
    script.on_event(defines.events.on_player_removed, on_player_change)
    script.on_event(defines.events.on_player_kicked, on_player_change)
    script.on_event(defines.events.on_player_banned, on_player_change)

    script.on_event(defines.events.on_player_died, on_player_died)

    script.on_nth_tick(300, collect_metrics)

    on_player_change()
    collect_metrics()
end

script.on_init(init)

-- TODO: check if this is a legitimate use of `on_load`
-- See https://lua-api.factorio.com/latest/classes/LuaBootstrap.html#on_load
script.on_load(init)
