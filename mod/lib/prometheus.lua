local function zip(lhs, rhs)
    if lhs == nil or rhs == nil then
        return {}
    end

    local len = math.min(#lhs, #rhs)
    local result = {}
    for i = 1, len do
        table.insert(result, { lhs[i], rhs[i] })
    end
    return result
end

local function escape_string(str)
    return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub('"', '\\"')
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

local function labels_to_string(label_pairs)
    if #label_pairs == 0 then
        return ""
    end

    local label_parts = {}
    for _, label in ipairs(label_pairs) do
        local label_name = label[1]
        local label_value = label[2]
        local label_value_escaped = escape_string(string.format("%s", label_value))
        table.insert(label_parts, label_name .. '="' .. label_value_escaped .. '"')
    end

    return "{" .. table.concat(label_parts, ",") .. "}"
end

-- ###

local Gauge = {}
Gauge.__index = Gauge

function Gauge.new(id, name, labels)
    if type(id) ~= "string" then
        error("Missing string parameter `id`")
    end

    if type(name) ~= "string" then
        error("Missing string parameter `name`")
    end

    local obj = {
        id = id,
        name = name,
        labels = labels or {},
        observations = {},
        label_values = {},
    }

    setmetatable(obj, Gauge)

    return obj
end

function Gauge:set(value, label_values)
    if type(value) ~= "number" then
        error("Missing number parameter `val`")
    end

    label_values = label_values or {}
    local key = table.concat(label_values, "\0")
    self.observations[key] = value
    self.label_values[key] = label_values
end

function Gauge:collect()
    local result = {}

    table.insert(result, "# HELP " .. self.id .. " " .. escape_string(self.name))
    table.insert(result, "# TYPE " .. self.id .. " gauge")

    for key, observation in pairs(self.observations) do
        local label_values = self.label_values[key]
        local prefix = self.id
        local labels = zip(self.labels, label_values)

        local str = prefix .. labels_to_string(labels) .. " " .. metric_to_string(observation)
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

function Registry:remove_id(id)
    local id_long = self.id_prefix .. id

    if self.collectors[id_long] ~= nil then
        table.remove(self.collectors, id_long)
    else
        error("No such collector id `" .. id_long .. "`")
    end
end

function Registry:collect()
    local result = {}
    for _, collector in pairs(self.collectors) do
        for _, metric in ipairs(collector:collect()) do
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
