-- main.lua
local BASE_URL = "https://raw.githubusercontent.com/doedie00-source/Traderepo/refs/heads/main/"

local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    gui = BASE_URL .. "gui.lua",
}

local function loadModule(url, name)
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success then return nil end
    local func, err = loadstring(result)
    if not func then return nil end
    return func()
end

print("🚀 Loading Universal Trade System V7.1...")

local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")
local GUI = loadModule(MODULES.gui, "gui")

if not (Config and Utils and UIFactory and StateManager and InventoryManager and TradeManager and GUI) then
    error("❌ Critical module failed to load.")
    return
end

-- [จุดที่แก้ไข] เชื่อมต่อ Config เข้ากับ Module ต่างๆ โดยตรง
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

if CoreGui:FindFirstChild(Config.CONFIG.GUI_NAME) then
    CoreGui[Config.CONFIG.GUI_NAME]:Destroy()
end

local app = GUI.new({
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager
})

app:Initialize()
print("✅ System Loaded! Press [T] to toggle.")
