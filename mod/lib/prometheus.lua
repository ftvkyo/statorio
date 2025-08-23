local function escape_string(str)
    return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub('"', '\\"')
end

local function labels_to_key(names, values)
    if names == nil and values == nil then
        return ""
    end

    assert(type(names) == "table")
    assert(type(values) == "table")
    assert(#names == #values, "The numbers of label names and label values differ")

    local result = {}
    for i = 1, #names do
        local name = names[i]
        local value = string.format("%s", values[i])

        table.insert(result, name .. "=\"" .. escape_string(value) .. "\"")
    end

    if #result == 0 then
        return ""
    end

    return "{" .. table.concat(result, ",") .. "}"
end

local function metric_to_string(value)
    if value == math.huge then
        return "+Inf"
    elseif value == -math.huge then
        return "-Inf"
    elseif value ~= value then
        return "NaN"
    else
        return tostring(value)
    end
end

-- ###

local function validate_id(id)
    assert(type(id) == "string")

    for _ in id:gmatch("%s") do
        error("Parameter `id` must not contain spaces, but it is `" .. id .. "`")
    end
end

local function validate_name(name)
    assert(type(name) == "string")
end

-- ###

local Gauge = {}
Gauge.__index = Gauge

function Gauge.new(id, name, label_names)
    validate_id(id)
    validate_name(name)

    local obj = {
        id = id,
        name = name,
        observations = {},
        label_names = label_names,
    }

    setmetatable(obj, Gauge)

    return obj
end

function Gauge:set(num, label_values)
    assert(type(num) == "number")

    local label_key = labels_to_key(self.label_names, label_values)
    self.observations[label_key] = num
end

function Gauge:collect_metrics()
    local result = {}

    if next(self.observations) == nil then
        return {}
    end

    table.insert(result, "# HELP " .. self.id .. " " .. escape_string(self.name))
    table.insert(result, "# TYPE " .. self.id .. " gauge")

    for label_key, observation in pairs(self.observations) do
        local str = self.id .. label_key .. " " .. metric_to_string(observation)
        table.insert(result, str)
    end

    return result
end

-- ###

local Counter = {}
Counter.__index = Counter

function Counter.new(id, name, label_names)
    validate_id(id)
    validate_name(name)

    local obj = {
        id = id,
        name = name,
        observations = {},
        label_names = label_names,
    }

    setmetatable(obj, Counter)

    return obj
end

function Counter:increment(num, label_values)
    assert(type(num) == "number")
    assert(num >= 0, "Tried to decrement a counter")

    local label_key = labels_to_key(self.label_names, label_values)
    local old_value = self.observations[label_key] or 0
    self.observations[label_key] = old_value + num
end

function Counter:collect_metrics()
    local result = {}

    if next(self.observations) == nil then
        return {}
    end

    table.insert(result, "# HELP " .. self.id .. " " .. escape_string(self.name))
    table.insert(result, "# TYPE " .. self.id .. " counter")

    for label_key, observation in pairs(self.observations) do
        local str = self.id .. label_key .. " " .. metric_to_string(observation)
        table.insert(result, str)
    end

    return result
end

-- ###

local Registry = {}
Registry.__index = Registry

function Registry.new(id_prefix)
    local obj = {
        id_prefix = id_prefix or "",
        collectors = {},
    }

    setmetatable(obj, Registry)

    return obj
end

function Registry:new_gauge(id, name, labels)
    local id_long = self.id_prefix .. id

    if self.collectors[id_long] ~= nil then
        error("Collector id `" .. id_long .. "` is already registered")
    end

    local collector = Gauge.new(id_long, name, labels)
    self.collectors[id_long] = collector
    return collector
end

function Registry:new_counter(id, name, labels)
    local id_long = self.id_prefix .. id

    if self.collectors[id_long] ~= nil then
        error("Collector id `" .. id_long .. "` is already registered")
    end

    local collector = Counter.new(id_long, name, labels)
    self.collectors[id_long] = collector
    return collector
end

function Registry:collect_metrics()
    local result = {}
    for _, collector in pairs(self.collectors) do
        for _, metric in ipairs(collector:collect_metrics()) do
            table.insert(result, metric)
        end
        table.insert(result, "")
    end

    return table.concat(result, "\n") .. "\n"
end

-- ###

return {
    Registry = Registry,
}
