local prometheus = require("lib/prometheus/prometheus")

local registry = prometheus.Registry.new("factorio_")

local gauges = {}
local counters = {}

local function collect_metrics()
    -- helpers.write_file("statorio/game.prom", registry:collect_metrics(), false, 0)
    helpers.write_file("statorio/game.prom", registry:collect_metrics(), false)
end

--- @overload fun(event:EventData.on_player_joined_game)
--- @overload fun(event:EventData.on_player_left_game)
--- @overload fun(event:EventData.on_player_removed)
--- @overload fun(event:EventData.on_player_kicked)
--- @overload fun(event:EventData.on_player_banned)
--- @overload fun(event:EventData.on_player_unbanned)
local function on_player_change(event)
    gauges.players_connected:set(#game.connected_players)
    gauges.players_total:set(#game.players)
end

--- @param event EventData.on_player_died
local function on_player_died(event)
    local player = game.get_player(event.player_index)
    if player ~= nil then
        counters.player_deaths:increment_by(1, { player.force.name, player.name })
    end
end

--- @overload fun(event:EventData.on_player_built_tile)
--- @overload fun(event:EventData.on_robot_built_tile)
local function on_tile_built(event)
    local tile = event.tile
    local surface = game.get_surface(event.surface_index)
    if surface ~= nil then
        gauges.area_paved:increment_by(#event.tiles, { surface.name, tile.name })
    end
end

--- @overload fun(event:EventData.on_player_mined_tile)
--- @overload fun(event:EventData.on_robot_mined_tile)
local function on_tile_mined(event)
    local surface = game.get_surface(event.surface_index)
    if surface ~= nil then
        for _, tile in ipairs(event.tiles) do
            gauges.area_paved:decrement_by(1, { surface.name, tile.old_tile.name })
        end
    end
end

--- @param event EventData.on_rocket_launched
local function on_rocket_launched(event)
    local silo = event.rocket_silo
    if silo ~= nil then
        counters.rockets_launched:increment_by(1, { silo.surface.name, silo.force.name })
    end
end

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    counters.researches_finished:increment_by(1, { event.research.force.name })
end

--- Every 1 second
--- @param event NthTickEventData
local function on_60th_tick(event)
    counters.ticks_played:set(game.tick)
    collect_metrics()
end

--- @param surface LuaSurface
local function refresh_pollution(surface)
    local pollution = surface:get_total_pollution()
    gauges.pollution:set(pollution, { surface.name })

    local pollution_statistics = game.get_pollution_statistics(surface)

    for name, num in pairs(pollution_statistics.input_counts) do
        gauges.pollution_produced:set(num, { surface.name, name })
    end

    for name, num in pairs(pollution_statistics.output_counts) do
        gauges.pollution_consumed:set(num, { surface.name, name })
    end
end

--- @param surface LuaSurface
local function refresh_evolution(surface)
    local enemy = game.forces["enemy"]

    if enemy ~= nil then
        local evolution = enemy.get_evolution_factor(surface)
        gauges.evolution:set(evolution, { surface.name })

        local evolution_by_killing_spawners = enemy.get_evolution_factor_by_killing_spawners(surface)
        gauges.evolution_by_cause:set(evolution_by_killing_spawners, { surface.name, "killing_spawners" })

        local evolution_by_pollution = enemy.get_evolution_factor_by_pollution(surface)
        gauges.evolution_by_cause:set(evolution_by_pollution, { surface.name, "pollution" })

        local evolution_by_time = enemy.get_evolution_factor_by_time(surface)
        gauges.evolution_by_cause:set(evolution_by_time, { surface.name, "time" })
    end
end

--- Every 10 seconds
--- @param event NthTickEventData
local function on_600th_tick(event)
    for _, surface in pairs(game.surfaces) do
        if surface.pollutant_type ~= nil then
            refresh_pollution(surface)
            refresh_evolution(surface)
        end
    end
end

local function load()
    gauges.players_connected = registry:new_gauge("players_connected", "Players connected")
    gauges.players_total = registry:new_gauge("players_total", "Players total")

    -- Unfortunately, this goes wrong if a nuke destroys some tiles.
    -- There seems to be no easy way to fix it other than recount all tiles on a surface when a nuke explodes.
    -- So for now this is allowed to get out of sync.
    gauges.area_paved = registry:new_gauge("area_paved", "Area paved", { "surface", "tile" })

    gauges.pollution = registry:new_gauge("pollution", "Pollution level", { "surface" })
    gauges.pollution_produced = registry:new_gauge("pollution_produced", "Pollution produced", { "surface", "name" })
    gauges.pollution_consumed = registry:new_gauge("pollution_consumed", "Pollution consumed", { "surface", "name" })

    gauges.evolution = registry:new_gauge("evolution", "Evolution factor", { "surface" })
    gauges.evolution_by_cause = registry:new_gauge("evolution_by_cause", "Evolution factor by cause", { "surface", "cause" })

    counters.ticks_played = registry:new_counter("ticks_played", "Ticks passed")
    counters.player_deaths = registry:new_counter("player_deaths", "Player deaths", { "force", "name" })

    counters.rockets_launched = registry:new_counter("rockets_launched", "Rockets launched", { "surface", "force" })
    counters.researches_finished = registry:new_counter("researches_finished", "Researches finished", { "force" })

    collect_metrics()
end

local function init()
    if not storage.registry then
        storage.registry = {}
    end

    load()
end

script.on_event(defines.events.on_player_joined_game, on_player_change)
script.on_event(defines.events.on_player_left_game, on_player_change)
script.on_event(defines.events.on_player_removed, on_player_change)
script.on_event(defines.events.on_player_kicked, on_player_change)
script.on_event(defines.events.on_player_banned, on_player_change)
script.on_event(defines.events.on_player_unbanned, on_player_change)

script.on_event(defines.events.on_player_died, on_player_died)

script.on_event(defines.events.on_player_built_tile, on_tile_built)
script.on_event(defines.events.on_robot_built_tile, on_tile_built)

script.on_event(defines.events.on_player_mined_tile, on_tile_mined)
script.on_event(defines.events.on_robot_mined_tile, on_tile_mined)

script.on_event(defines.events.on_rocket_launched, on_rocket_launched)
script.on_event(defines.events.on_research_finished, on_research_finished)

script.on_nth_tick(60, on_60th_tick)
script.on_nth_tick(600, on_600th_tick)

script.on_init(init)

-- TODO: check if this is a legitimate use of `on_load`
-- See https://lua-api.factorio.com/latest/classes/LuaBootstrap.html#on_load
script.on_load(load)
