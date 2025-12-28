-- main.lua
-- Main Loader Script

local BASE_URL = "https://raw.githubusercontent.com/doedie00-source/Traderepo/refs/heads/main/"

local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    
    -- ไฟล์ Tab ใหม่
    tab_players = BASE_URL .. "tab_players.lua",
    tab_dupe = BASE_URL .. "tab_dupe.lua",
    
    -- GUI หลัก
    gui = BASE_URL .. "gui.lua",
}

local function loadModule(url, name)
    -- ใช้ pcall เผื่อเว็บล่มหรือ URL ผิด
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success then 
        warn("Failed to fetch: " .. name)
        return nil 
    end
    
    local func, err = loadstring(result)
    if not func then 
        warn("Failed to compile: " .. name .. " Error: " .. tostring(err))
        return nil 
    end
    
    return func()
end

print("🚀 Loading Universal Trade System V7.1 (Refactored)...")

-- 1. โหลด Core Modules
local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")

-- 2. โหลด Tab Modules
local TabPlayers = loadModule(MODULES.tab_players, "tab_players")
local TabDupe = loadModule(MODULES.tab_dupe, "tab_dupe")

-- 3. โหลด GUI Controller
local GUI = loadModule(MODULES.gui, "gui")

-- ตรวจสอบความครบถ้วน
if not (Config and Utils and UIFactory and StateManager and GUI and TabPlayers and TabDupe) then
    error("❌ Critical module failed to load. Check console for details.")
    return
end

-- Dependency Injection Setup
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- ลบ GUI เก่าออกก่อน
if CoreGui:FindFirstChild(Config.CONFIG.GUI_NAME) then
    CoreGui[Config.CONFIG.GUI_NAME]:Destroy()
end

-- เริ่มต้น GUI
local app = GUI.new({
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager,
    
    -- ส่ง Tab Classes เข้าไปให้ GUI เรียกใช้
    Tabs = {
        Players = TabPlayers,
        Dupe = TabDupe
    }
})

app:Initialize()

print("✅ System Loaded Successfully!")
