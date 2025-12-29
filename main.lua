-- main.lua (Modular Version)
local BASE_URL = "https://raw.githubusercontent.com/doedie00-source/Traderepo/refs/heads/main/"

local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    gui = BASE_URL .. "gui.lua",
    -- Tabs
    players_tab = BASE_URL .. "tabs/players_tab.lua",
    dupe_tab = BASE_URL .. "tabs/dupe_tab.lua",
    inventory_tab = BASE_URL .. "tabs/inventory_tab.lua",
}

local function loadModule(url, name)
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success then 
        warn("Failed to load " .. name .. ": " .. tostring(result))
        return nil 
    end
    local func, err = loadstring(result)
    if not func then 
        warn("Failed to compile " .. name .. ": " .. tostring(err))
        return nil 
    end
    return func()
end

print("⚡ Loading Universal Trade System V7.3 (Auto-Detect Hidden Lists)...")

-- Load Core Modules
local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")
local GUI = loadModule(MODULES.gui, "gui")

-- Load Tabs
local PlayersTab = loadModule(MODULES.players_tab, "players_tab")
local DupeTab = loadModule(MODULES.dupe_tab, "dupe_tab")
local InventoryTab = loadModule(MODULES.inventory_tab, "inventory_tab")

if not (Config and Utils and UIFactory and StateManager and InventoryManager and TradeManager and GUI) then
    error("❌ Critical module failed to load.")
    return
end

if not (PlayersTab and DupeTab) then
    error("❌ Tab modules failed to load.")
    return
end

-- ✨ AUTO-DETECT HIDDEN LISTS
print("🔍 Detecting hidden lists from game...")
local detectedLists = Utils.ExtractHiddenLists()

-- ตรวจสอบและใช้ค่าที่ detect ได้
local finalHiddenLists = {}
for category, list in pairs(detectedLists) do
    if #list > 0 then
        finalHiddenLists[category] = list
        print("✅ " .. category .. ": Detected " .. #list .. " hidden items")
    else
        finalHiddenLists[category] = Config.HIDDEN_LISTS_FALLBACK[category] or {}
        print("⚠️ " .. category .. ": Using fallback (" .. #finalHiddenLists[category] .. " items)")
    end
end

-- อัพเดท Config
Config.HIDDEN_LISTS = finalHiddenLists

-- Link Configs
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- Cleanup Old GUI
if CoreGui:FindFirstChild(Config.CONFIG.GUI_NAME) then
    CoreGui[Config.CONFIG.GUI_NAME]:Destroy()
end

-- Create App
local app = GUI.new({
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager,
    Tabs = {
        Players = PlayersTab,
        Dupe = DupeTab,
        Inventory = InventoryTab
    }
})

app:Initialize()
print("✅ System Loaded! Press [T] to toggle.")
print("🎨 Hidden Lists: " .. #finalHiddenLists.Accessories .. " Accessories, " .. #finalHiddenLists.Secrets .. " Secrets, " .. #finalHiddenLists.Crates .. " Crates")
