local DB = require "utils.db"
local cjson = require "cjson"
local http = require "resty.http"
local os = require "os"
local io = require "io"

local CandyPanel = {}
CandyPanel.__index = CandyPanel

function CandyPanel:new()
    local self = setmetatable({}, CandyPanel)
    self.db = DB:new("Candy-Panel-PPTP-L2TP.db")
    return self
end
