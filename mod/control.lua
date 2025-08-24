local prometheus = require("lib/prometheus")

local registry = prometheus.Registry.new("factorio_")

local gauges = {}
local counters = {}

local function collect_metrics()
    -- helpers.write_file("statorio/game.prom", registry:collect_metrics(), false, 0)
    helpers.write_file("statorio/game.prom", registry:collect_metrics(), false)
end

local function on_player_change(event)
    gauges.players_connected:set(#game.connected_players)
    gauges.players_total:set(#game.players)
end

local function on_player_died(event)
    counters.player_deaths:increment_by(1)
end

local function on_tile_built(event)
    local tile_name = event.tile.name
    local surface_name = game.get_surface(event.surface_index).name

    gauges.area_paved:increment_by(#event.tiles, { tile_name, surface_name })
end

local function on_tile_mined(event)
    local surface_name = game.get_surface(event.surface_index).name
    for _, tile in ipairs(event.tiles) do
        local tile_name = tile.old_tile.name
        gauges.area_paved:decrement_by(1, { tile_name, surface_name })
    end
end

local function on_300th_tick(event)
    counters.ticks_played:set(game.tick)
    collect_metrics()
end

local function on_600th_tick(event)
    for _, surface in pairs(game.surfaces) do
        local pollution = surface:get_total_pollution()
        gauges.pollution:set(pollution, { surface.name })
    end
end

local function load()
    gauges.players_connected = registry:new_gauge("players_connected", "Players connected")
    gauges.players_total = registry:new_gauge("players_total", "Players total")

    gauges.area_paved = registry:new_gauge("area_paved", "Area paved", { "tile", "surface" })

    gauges.pollution = registry:new_gauge("pollution", "Total pollution", { "surface" })

    counters.ticks_played = registry:new_counter("ticks_played", "Ticks passed")
    counters.player_deaths = registry:new_counter("player_deaths", "Player deaths")

    script.on_event(defines.events.on_player_joined_game, on_player_change)
    script.on_event(defines.events.on_player_left_game, on_player_change)
    script.on_event(defines.events.on_player_removed, on_player_change)
    script.on_event(defines.events.on_player_kicked, on_player_change)
    script.on_event(defines.events.on_player_banned, on_player_change)

    script.on_event(defines.events.on_player_died, on_player_died)

    script.on_event(defines.events.on_player_built_tile, on_tile_built)
    script.on_event(defines.events.on_robot_built_tile, on_tile_built)

    script.on_event(defines.events.on_player_mined_tile, on_tile_mined)
    script.on_event(defines.events.on_robot_mined_tile, on_tile_mined)

    script.on_nth_tick(300, on_300th_tick)
    script.on_nth_tick(600, on_600th_tick)

    collect_metrics()
end

local function init()
    if not storage.registry then
        storage.registry = {}
    end

    load()
end

script.on_init(init)

-- TODO: check if this is a legitimate use of `on_load`
-- See https://lua-api.factorio.com/latest/classes/LuaBootstrap.html#on_load
script.on_load(load)
