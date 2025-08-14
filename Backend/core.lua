local DB = require "utils.db"
local cjson = require "cjson"
local http = require "resty.http"
local os = require "os"
local io = require "io"

local installcommands = {
    "sudo apt update && sudo apt upgrade -y",
    "sudo apt install -y pptpd",
    "sudo apt install -y strongswan xl2tpd",
    "sudo sysctl -w net.ipv4.ip_forward=1",
    "sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'",
    "sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
    "sudo ufw allow 1723/tcp",
    "sudo ufw allow proto 47",
    "sudo ufw allow 500/udp",
    "sudo ufw allow 4500/udp",
    "sudo ufw allow 1701/udp",
    "sudo systemctl restart pptpd",
    "sudo systemctl restart xl2tpd",
    "sudo systemctl restart strongswan",
    "sudo systemctl enable pptpd",
    "sudo systemctl enable xl2tpd",
    "sudo systemctl enable strongswan"
}
local CandyPanel = {}
CandyPanel.__index = CandyPanel

function CandyPanel:new()
    local self = setmetatable({}, CandyPanel)
    self.db = DB:new("Candy-Panel-PPTP-L2TP.db")
    return self
end

function CandyPanel:_reloadVPN()
    print("Reloading VPN services...")
    local success, err = pcall(function()
        local result = os.execute("sudo systemctl restart pptpd && sudo systemctl restart xl2tpd")
        if result ~= 0 then
            error("Failed to reload VPN services")
        end
    end)
    if not success then
        print("Failed to reload VPN services: " .. err)
        return false, "Failed to reload VPN services"
    end
    return true, "VPN services reloaded successfully"
end
function CandyPanel:_mapPPPs()
    local f = io.open("/var/log/ppp.log", "r")
    if not f then return end

    for line in f:lines() do
        local iface, user = line:match("(%S+) connected to .- as (%S+)")
        if iface and user then
            self.db:query("UPDATE clients SET ppp_iface = ? WHERE username = ?", { iface, user })
        end
    end

    f:close()
end

function CandyPanel:updateTraffic()
    local f = io.open("/proc/net/dev", "r")
    if not f then return false, "Cannot read /proc/net/dev" end
    local iface_traffic = {}
    for line in f:lines() do
        local iface, rx, tx = line:match("(%S+):%s*(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
        if iface and iface:match("^ppp") then
            iface_traffic[iface] = { rx = tonumber(rx), tx = tonumber(tx) }
        end
    end
    f:close()
    return iface_traffic
end

function CandyPanel:InstallCandyPanel()
    print("Starting installation of PPTP and L2TP VPN...")
    if not self.db:has('settings', { key = 'install', value = '0' }) then
        print("Candy Panel is already installed.")
        return false, "Candy Panel is already installed"
    end
    local success, err = pcall(function()
        for _, cmd in ipairs(installcommands) do
            local result = os.execute(cmd)
            if result ~= 0 then
                error("Command failed: " .. cmd)
            end
        end
    end)
    if not success then
        print("Installation failed: " .. err)
        return false, "Installation failed"
    end
    self.db:query("UPDATE settings SET value = '1' WHERE key = 'install'")
    print("Installation finished. PPTP and L2TP/IPsec servers are installed.")
    return true , "Installation successful"
end

function CandyPanel:getDashboardData()
    local data = {
        clients = self.db:select('clients'),
        settings = self.db:select('settings'),
        server_stats = {
            memory = {
                total = collectgarbage("count"),
                used = collectgarbage("count", "used"),
                percent = collectgarbage("count") / collectgarbage("count", "total") * 100
            },
            cpu = os.execute("top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/'") or 0,
            network = {
                download = io.popen("cat /proc/net/dev | grep eth0 | awk '{print $2}'"):read("*n") or 0,
                upload = io.popen("cat /proc/net/dev | grep eth0 | awk '{print $10}'"):read("*n") or 0
            }
        }
    }
    return data
end

function CandyPanel:changeSetting(key, value)
    local success, err = pcall(function()
        self.db:query("UPDATE settings SET value = ? WHERE key = ?", { value, key })
    end)
    if not success then
        print("Failed to change setting: " .. err)
        return false, "Failed to change setting"
    end
    return true, "Setting changed successfully"
end

function CandyPanel:newUser(username, password, traffic, expire)
    if not username or not password then
        return false, "Username and password are required"
    end

    local success, err = pcall(function()
        self.db:insert('clients', { username = username, password = password, traffic = traffic, expire = expire })
    end)
    if not success then
        print("Failed to create user in DB: " .. err)
        return false, "Failed to create user in DB"
    end

    local file = "/etc/ppp/chap-secrets"
    local entry = string.format("%s\t*\t%s\t*\n", username, password)
    local ok, eerr = pcall(function()
        local f = io.open(file, "a")
        if not f then error("Cannot open " .. file) end
        f:write(entry)
        f:close()
    end)
    if not ok then
        print("Failed to add user to PPTP: " .. eerr)
        return false, "Failed to add user to PPTP"
    end
    self:_reloadVPN()
    return true, "User created successfully for DB, PPTP, and L2TP"
end

function CandyPanel:editUser(username, new_password, new_traffic, new_expire)
    if not username then
        return false, "Username is required"
    end
    local success, err = pcall(function()
        local user = self.db:get('clients', { username = username })
        if not user then
            return false, "User not found"
        end
        self.db:query("UPDATE clients SET password = ?, traffic = ?, expire = ? WHERE username = ?",
            { new_password, new_traffic, new_expire, username })
        local file = "/etc/ppp/chap-secrets"
        local ok, eerr = pcall(function()
            local f = io.open(file, "r")
            if not f then error("Cannot open " .. file) end
            local lines = {}
            for line in f:lines() do
                if not line:match("^" .. username .. "\t") then
                    table.insert(lines, line)
                end
            end
            f:close()
            table.insert(lines, string.format("%s\t*\t%s\t*\n", username, new_password))
            f = io.open(file, "w")
            if f then
                for _, line in ipairs(lines) do
                    f:write(line .. "\n")
                end
                f:close()
            end
        end)
        if not ok then
            print("Failed to edit user in PPTP: " .. eerr)
            return false, "Failed to edit user in PPTP"
        end
    end)
    if not success then
        print("Failed to edit user: " .. err)
        return false, "Failed to edit user"
    end
    self:_reloadVPN()
    return true, "User edited successfully for DB, PPTP, and L2TP"
end

function CandyPanel:deleteUser(username)
    if not username then
        return false, "Username is required"
    end
    local success, err = pcall(function()
        self.db:query("DELETE FROM clients WHERE username = ?", { username })
        local file = "/etc/ppp/chap-secrets"
        local ok, eerr = pcall(function()
            local f = io.open(file, "r")
            if not f then error("Cannot open " .. file) end
            local lines = {}
            for line in f:lines() do
                if not line:match("^" .. username .. "\t") then
                    table.insert(lines, line)
                end
            end
            f:close()
            f = io.open(file, "w")
            if f then
                for _, line in ipairs(lines) do
                    f:write(line .. "\n")
                end
                f:close()
            end
        end)
        if not ok then
            print("Failed to delete user from PPTP: " .. eerr)
            return false, "Failed to delete user from PPTP"
        end
    end)
    if not success then
        print("Failed to delete user: " .. err)
        return false, "Failed to delete user"
    end
    self:_reloadVPN()
    return true, "User deleted successfully from DB, PPTP, and L2TP"
end

function CandyPanel:sync()
    local users = self.db:query("SELECT * FROM clients")
    for _, user in ipairs(users) do
        self:_mapPPPs()
        local iface_traffic = self:updateTraffic() or {}
        local iface = user.ppp_iface
        if iface and iface_traffic[iface] then
            local total = (iface_traffic[iface].rx + iface_traffic[iface].tx) / (1024 * 1024)
            self.db:query("UPDATE clients SET traffic = ? WHERE username = ?", { total, user.username })
        end
        if user.expire and os.time() > user.expire then
            self:deleteUser(user.username)
        end
    end
    return true, "All users synchronized successfully"
end