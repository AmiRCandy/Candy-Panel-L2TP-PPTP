local lapis = require "lapis"
local cjson = require "cjson"
local core = require "core"
local io = require "io"

local app = lapis.Application()

local function handle_json_request(self, handler)
    local body = self.req.body
    if not body then
        return { json = { success = false, message = "No request body" } }
    end
    
    local data = cjson.decode(body)
    if not data then
        return { json = { success = false, message = "Invalid JSON" } }
    end
    
    local success, response = pcall(handler, self, data)
    
    if not success then
        return { json = { success = false, message = "Internal Server Error" } }
    end
    
    return { json = response }
end

app:get("/", function(self)
    local f = io.open("../frontend/index.html", "r")
    if not f then
        return { status = 404, ["content-type"] = "text/plain", body = "File not found" }
    end
    local content = f:read("*a")
    f:close()
    return { ["content-type"] = "text/html", body = content }
end)

app:get("/dashboard", function(self)
    local Candy = core.CandyPanel:new()
    local data = Candy:getDashboardData()
    return { json = data }
end)

app:post("/install", function(self)
    return handle_json_request(self, function(_, data)
        local psk = data.psk
        local Candy = core.CandyPanel:new()
        local success, msg = Candy:InstallCandyPanel(psk)
        return { success = success, message = msg }
    end)
end)

app:post("/user", function(self)
    return handle_json_request(self, function(_, data)
        local Candy = core.CandyPanel:new()
        local action = data.action
        
        if action == 'new_user' then
            local username = data.username
            local password = data.password
            local traffic = data.traffic or 0
            local expire = data.expire or 0
            local success, err = Candy:newUser(username, password, traffic, expire)
            if success then
                return { message = "User created successfully", user = { username = username, traffic = traffic, expire = expire } }
            else
                return { message = "Failed to create user", error = err }
            end
        elseif action == 'edit_user' then
            local username = data.username
            local password = data.password
            local traffic = data.traffic or 0
            local expire = data.expire or 0
            local success, err = Candy:editUser(username, password, traffic, expire)
            if success then
                return { message = "User edited successfully", user = { username = username, traffic = traffic, expire = expire } }
            else
                return { message = "Failed to edit user", error = err }
            end
        elseif action == 'delete_user' then
            local username = data.username
            if not username then
                return { message = "Username is required for deletion" }
            end
            local success, err = Candy:deleteUser(username)
            if success then
                return { message = "User deleted successfully" }
            else
                return { message = "Failed to delete user", error = err }
            end
        end
        return { message = "Invalid action" }
    end)
end)

app:post("/settings", function(self)
    return handle_json_request(self, function(_, data)
        local Candy = core.CandyPanel:new()
        local key = data.key
        local value = data.value
        local success, err = Candy:changeSetting(key, value)
        if success then
            return { message = "Setting changed successfully" }
        else
            return { message = "Failed to change setting", error = err }
        end
    end)
end)

return app