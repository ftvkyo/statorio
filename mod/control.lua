local prometheus = require("lib/prometheus")

local registry = prometheus.Registry.new("factorio_")

local gauge_players_connected = registry:new_gauge("players_connected", "Players connected")
local gauge_players_total = registry:new_gauge("players_total", "Players total")

local function refresh_players(event)
    gauge_players_connected:set(#game.connected_players)
    gauge_players_total:set(#game.players)
end

local function collect()
    -- helpers.write_file("statorio/game.prom", registry:collect(), false, 0)
    helpers.write_file("statorio/game.prom", registry:collect(), false)
end

local function init()
    script.on_event(defines.events.on_player_joined_game, refresh_players)
    script.on_event(defines.events.on_player_left_game, refresh_players)
    script.on_event(defines.events.on_player_removed, refresh_players)
    script.on_event(defines.events.on_player_kicked, refresh_players)
    script.on_event(defines.events.on_player_banned, refresh_players)

    script.on_nth_tick(300, collect)

    refresh_players()
    collect()
end

script.on_init(init)
script.on_load(init)
