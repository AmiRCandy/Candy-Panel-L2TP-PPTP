local cjson = require "cjson"
local core = require "core"

local Candy = core.CandyPanel:new()
ngx.header.content_type = "application/json"
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)
if data then
    local key = data.key
    local value = data.value
    local success, err = Candy:changeSetting(key, value)
    if success then
        ngx.say(cjson.encode({ message = "Setting changed successfully" }))
    else
        ngx.say(cjson.encode({ message = "Failed to change setting", error = err }))
    end
end