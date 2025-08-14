local sqlite3 = require "lsqlite3"

local DB = {}
DB.__index = DB

function DB:new(file)
    local self = setmetatable({}, DB)
    self.conn = sqlite3.open(file)
     self:query([[
        CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            traffic INTEGER DEFAULT 0,
            used_traffic INTEGER DEFAULT 0,
            expire INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            status BOOLEAN DEFAULT TRUE
        )
    ]])

    self:query([[
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT,
            value TEXT
        )
    ]])
    if self:count('settings') == 0 then
        self:insert('settings', { key = 'status', value = '1' })
        self:insert('settings', { key = 'custom_endpoint', value = '192.168.1.1' })
        self:insert('settings', { key = 'install', value = '0' })
    end
    return self
end

function DB:query(sql, params)
    local stmt = self.conn:prepare(sql)
    if not stmt then
        error("Failed to prepare SQL: " .. sql)
    end
    if params then
        for k, v in ipairs(params) do
            stmt:bind(k, v)
        end
    end
    local results = {}
    for row in stmt:nrows() do
        table.insert(results, row)
    end
    stmt:finalize()
    return results
end

function DB:insert(tableName, data)
    local keys, placeholders, values = {}, {}, {}
    for k, v in pairs(data) do
        table.insert(keys, k)
        table.insert(placeholders, "?")
        table.insert(values, v)
    end
    local sql = string.format(
        "INSERT INTO %s (%s) VALUES (%s)",
        tableName,
        table.concat(keys, ", "),
        table.concat(placeholders, ", ")
    )
    self:query(sql, values)
end

function DB:select(tableName, where)
    local sql = "SELECT * FROM " .. tableName
    local params = {}
    if where then
        local clauses = {}
        for k, v in pairs(where) do
            table.insert(clauses, k .. " = ?")
            table.insert(params, v)
        end
        sql = sql .. " WHERE " .. table.concat(clauses, " AND ")
    end
    return self:query(sql, params)
end

function DB:get(tableName, where)
    local results = self:select(tableName, where)
    if #results > 0 then
        return results[1]
    end
    return nil
end

function DB:has(tableName, where)
    local row = self:get(tableName, where)
    return row ~= nil
end

function DB:count(tableName, where)
    local sql = "SELECT COUNT(*) as count FROM " .. tableName
    local params = {}
    if where then
        local clauses = {}
        for k, v in pairs(where) do
            table.insert(clauses, k .. " = ?")
            table.insert(params, v)
        end
        sql = sql .. " WHERE " .. table.concat(clauses, " AND ")
    end
    local results = self:query(sql, params)
    return results[1] and results[1].count or 0
end

function DB:close()
    self.conn:close()
end

return DB