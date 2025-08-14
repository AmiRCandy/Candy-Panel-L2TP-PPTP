local cjson = require "cjson"
local core = require "core"

local Candy = core.CandyPanel:new()
ngx.header.content_type = "application/json"
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)
local psk = data.psk
local success, msg = Candy:InstallCandyPanel(psk)
ngx.say(cjson.encode({ success = success, message = msg }))