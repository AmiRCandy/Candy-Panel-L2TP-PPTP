local cjson = require "cjson"
local core = require "core"

local Candy = core.CandyPanel:new()
ngx.header.content_type = "application/json"
local data = Candy:getDashboardData()
ngx.say(cjson.encode(data))