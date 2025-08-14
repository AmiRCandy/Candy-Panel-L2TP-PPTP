#!/usr/bin/env lua

package.path = "/var/www/candy-panel/backend/?.lua;;;"

local core = require "core"
local Candy = core.CandyPanel:new()


local success, message = Candy:sync()
if success then
    print("Sync process completed: " .. message)
else
    print("Sync process failed: " .. message)
end