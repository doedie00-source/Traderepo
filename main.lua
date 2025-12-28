-- main.lua
-- Loader หลักของระบบ TradeSys V7.1 Refactored
-- โหลด Modules ทั้งหมดและทำ Dependency Injection

local BASE_URL = "https://raw.githubusercontent.com/doedie00-source/Traderepo/refs/heads/main/"

-- รายชื่อไฟล์ทั้งหมดที่ต้องโหลด
local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    
    -- ไฟล์ใหม่ที่เราเพิ่งแยก
    tab_players = BASE_URL .. "tab_players.lua",
    tab_dupe = BASE_URL .. "tab_dupe.lua",
    
    -- GUI ตัวใหม่
    gui = BASE_URL .. "gui.lua",
}

-- ฟังก์ชันโหลด Script จาก URL
local function loadModule(url, name)
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success then 
        warn("❌ Failed to fetch: " .. name)
        return nil 
    end
    
    local func, err = loadstring(result)
    if not func then 
        warn("❌ Failed to compile: " .. name .. " Error: " .. tostring(err))
        return nil 
    end
    
    return func()
end

print("🚀 Starting TradeSys V7.1 (Refactored)...")

-- 1. โหลด Core Modules
local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")

-- 2. โหลด Tab Modules (ไฟล์ใหม่)
local TabPlayers = loadModule(MODULES.tab_players, "tab_players")
local TabDupe = loadModule(MODULES.tab_dupe, "tab_dupe")

-- 3. โหลด GUI
local GUI = loadModule(MODULES.gui, "gui")

-- ตรวจสอบว่าโหลดครบไหม
if not (Config and Utils and UIFactory and StateManager and GUI and TabPlayers and TabDupe) then
    error("❌ Critical module failed to load. Check console.")
    return
end

-- 4. ตั้งค่า Dependency Injection (เชื่อม Config เข้ากับระบบ)
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

-- 5. เริ่มต้นระบบ GUI
local app = GUI.new({
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager,
    
    -- ส่ง Tab Classes เข้าไปให้ GUI รู้จัก
    Tabs = {
        Players = TabPlayers,
        Dupe = TabDupe
    }
})

app:Initialize()

print("✅ TradeSys Loaded Successfully!")
