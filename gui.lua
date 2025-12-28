-- main.lua
local BASE_URL = "https://raw.githubusercontent.com/doedie00-source/Traderepo/refs/heads/main/"

-- เปลี่ยน URL ตรงนี้ให้เป็น Link ของไฟล์ที่คุณแยกใหม่ด้วยนะครับ
local MODULES = {
    config = BASE_URL .. "config.lua",
    utils = BASE_URL .. "utils.lua",
    ui_factory = BASE_URL .. "ui_factory.lua",
    state_manager = BASE_URL .. "state_manager.lua",
    inventory_manager = BASE_URL .. "inventory_manager.lua",
    trade_manager = BASE_URL .. "trade_manager.lua",
    
    -- ไฟล์ใหม่ที่แยกออกมา (ถ้าเทสใน Studio ใช้ require แทนได้)
    gui = BASE_URL .. "gui.lua", 
    tab_players = BASE_URL .. "tab_players.lua",
    tab_dupe = BASE_URL .. "tab_dupe.lua",
}

local function loadModule(url, name)
    -- ถ้าเทสใน Roblox Studio ให้แก้ตรงนี้เป็น require(script.Parent.Modules[name])
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success then warn("Failed to load " .. name) return nil end
    local func, err = loadstring(result)
    if not func then warn("Error loading " .. name .. ": " .. err) return nil end
    return func()
end

print("🚀 Loading Universal Trade System V7.1 (Modular)...")

-- 1. Load Core Modules
local Config = loadModule(MODULES.config, "config")
local Utils = loadModule(MODULES.utils, "utils")
local UIFactory = loadModule(MODULES.ui_factory, "ui_factory")
local StateManager = loadModule(MODULES.state_manager, "state_manager")
local InventoryManager = loadModule(MODULES.inventory_manager, "inventory_manager")
local TradeManager = loadModule(MODULES.trade_manager, "trade_manager")

-- 2. Inject Config dependencies
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

-- 3. Load GUI & Tabs
local GUI = loadModule(MODULES.gui, "gui")
local TabPlayers = loadModule(MODULES.tab_players, "tab_players")
local TabDupe = loadModule(MODULES.tab_dupe, "tab_dupe")

if not (GUI and TabPlayers and TabDupe) then
    error("❌ Critical GUI modules failed to load.")
    return
end

-- 4. Setup Dependencies Bundle
local deps = {
    Config = Config,
    Utils = Utils,
    UIFactory = UIFactory,
    StateManager = StateManager,
    InventoryManager = InventoryManager,
    TradeManager = TradeManager
}

-- 5. Initialize App
local app = GUI.new(deps)

-- ลงทะเบียน Tabs (อยากเพิ่ม Tab ใหม่ มาใส่ตรงนี้ได้เลย)
app:RegisterTab("Players", "👥", TabPlayers.new(deps))
app:RegisterTab("Dupe", "✨", TabDupe.new(deps))

app:Initialize()
app:StartMonitoring() -- เริ่มระบบเช็คสถานะ Trade
