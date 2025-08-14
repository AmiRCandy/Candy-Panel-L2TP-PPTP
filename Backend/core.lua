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
        users = self.db:select('users'),
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