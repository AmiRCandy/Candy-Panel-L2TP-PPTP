local cjson = require "cjson"
local core = require "core"

local Candy = core.CandyPanel:new()
ngx.header.content_type = "application/json"
ngx.req.read_body()
local body = ngx.req.get_body_data()
local data = cjson.decode(body)
if data then
    if data.action == 'new_user' then
        local username = data.username
        local password = data.password
        local traffic = data.traffic or 0
        local expire = data.expire or 0
        local success, err = Candy:createUser(username, password, traffic, expire)
        if success then
            ngx.say(cjson.encode({ message = "User created successfully", user = { username = username, traffic = traffic, expire = expire } }))
        else
            ngx.say(cjson.encode({ message = "Failed to create user", error = err }))
        end
    elseif data.action == 'edit_user' then
        local username = data.username
        local password = data.password
        local traffic = data.traffic or 0
        local expire = data.expire or 0
        local success, err = Candy:editUser(username, password, traffic, expire)
        if success then
            ngx.say(cjson.encode({ message = "User edited successfully", user = { username = username, traffic = traffic, expire = expire } }))
        else
            ngx.say(cjson.encode({ message = "Failed to edit user", error = err }))
        end
    elseif data.action == 'delete_user' then
        local username = data.username
        if not username then
            ngx.say(cjson.encode({ message = "Username is required for deletion" }))
            return
        end
        local success, err = Candy:deleteUser(username)
        if success then
            ngx.say(cjson.encode({ message = "User deleted successfully" }))
        else
            ngx.say(cjson.encode({ message = "Failed to delete user", error = err }))
        end
    end
end