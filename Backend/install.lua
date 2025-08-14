local cjson = require "cjson"
local core = require "core"

local Candy = core.CandyPanel:new()
ngx.header.content_type = "application/json"
local msg , data = Candy:InstallCandyPanel()
ngx.say(cjson.encode({ message = msg, data = data }))