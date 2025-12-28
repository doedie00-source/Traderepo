-- main.lua
-- Universal Trade System V7.1 - Modular Entry Point
-- วางไฟล์ลง GitHub/Pastebin แล้วใช้ URL ด้านล่าง

local BASE_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/"
-- หรือ Pastebin: "https://pastebin.com/raw/"

-- 📦 Module URLs
local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    gui = BASE_URL .. "gui.lua",
}

-- 🔧 Helper Function
local function loadModule(url, name)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then
        warn("❌ Failed to load " .. name .. ": " .. tostring(result))
        return nil
    end
    
    local func, err = loadstring(result)
    if not func then
        warn("❌ Failed to compile " .. name .. ": " .. tostring(err))
        return nil
    end
    
    print("✅ Loaded: " .. name)
    return func()
end

-- 📥 Load All Modules
print("🚀 Loading Universal Trade System V7.1...")

local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")
local GUI = loadModule(MODULES.gui, "gui")

-- ⚠️ Validation
if not (Config and Utils and UIFactory and StateManager and InventoryManager and TradeManager and GUI) then
    error("❌ Critical module failed to load. Aborting.")
    return
end

-- 🎯 Initialize System
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Cleanup Old GUI
if CoreGui:FindFirstChild(Config.CONFIG.GUI_NAME) then
    CoreGui[Config.CONFIG.GUI_NAME]:Destroy()
end

-- 🚀 Start GUI
local app = GUI.new({
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager
})

app:Initialize()

print("✅ Universal Trade V7.1 (Modular) Loaded!")
print("📁 Press [T] to toggle GUI")
print("🔗 Modules loaded from: " .. BASE_URL)