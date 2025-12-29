-- main.lua (แก้ไขให้โหลดเสร็จก่อนเปิด GUI)
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

print("⚡ Loading Universal Trade System V7.3...")

-- ⏳ รอให้เกมโหลดเสร็จ
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

print("⏳ Waiting for game to load...")
repeat task.wait(0.5) until LocalPlayer and LocalPlayer.Character
task.wait(2) -- รอเพิ่มเติมให้แน่ใจ

print("✅ Game loaded, loading modules...")

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

if not (PlayersTab and DupeTab and InventoryTab) then
    error("❌ Tab modules failed to load.")
    return
end

print("✅ Modules loaded successfully!")

-- ✨✨✨ โหลด HIDDEN LISTS ก่อนเปิด GUI ✨✨✨
print("🔍 Detecting hidden lists... (please wait)")

local finalHiddenLists = {}
local detectionSuccess = false

-- ⏰ ลองตรวจจับ 3 ครั้ง (เผื่อครั้งแรกยังไม่พร้อม)
for attempt = 1, 3 do
    print("🔄 Attempt " .. attempt .. "/3...")
    
    local success, detectedLists = pcall(function()
        return Utils.ExtractHiddenLists()
    end)
    
    if success and detectedLists then
        local totalDetected = 0
        
        for category, list in pairs(detectedLists) do
            if #list > 0 then
                finalHiddenLists[category] = list
                totalDetected = totalDetected + #list
                print("   ✅ " .. category .. ": " .. #list .. " items")
            else
                finalHiddenLists[category] = Config.HIDDEN_LISTS_FALLBACK[category] or {}
                print("   ⚠️ " .. category .. ": fallback (" .. #finalHiddenLists[category] .. " items)")
            end
        end
        
        -- ถ้า detect ได้อย่างน้อย 1 category ให้ถือว่าสำเร็จ
        if totalDetected > 0 then
            detectionSuccess = true
            print("✅ Detection successful! Total: " .. totalDetected .. " hidden items")
            break
        end
    else
        warn("⚠️ Attempt " .. attempt .. " failed:", detectedLists or "unknown error")
    end
    
    if attempt < 3 then
        print("⏳ Waiting 3 seconds before retry...")
        task.wait(3)
    end
end

-- ถ้า detect ไม่สำเร็จเลย ใช้ fallback ทั้งหมด
if not detectionSuccess then
    warn("⚠️ All detection attempts failed, using fallback lists")
    finalHiddenLists = Config.HIDDEN_LISTS_FALLBACK
end

-- ตั้งค่า Hidden Lists ใน Config
Config.HIDDEN_LISTS = finalHiddenLists

print("📊 Final Hidden Lists:")
for category, list in pairs(finalHiddenLists) do
    print("   • " .. category .. ": " .. #list .. " items")
end

-- Link Configs
UIFactory.Config = Config
StateManager.Config = Config
TradeManager.Config = Config

local CoreGui = game:GetService("CoreGui")

-- Cleanup Old GUI
if CoreGui:FindFirstChild(Config.CONFIG.GUI_NAME) then
    CoreGui[Config.CONFIG.GUI_NAME]:Destroy()
end

print("🎨 Creating GUI...")

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

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ SYSTEM READY!")
print("🎯 Press [T] to toggle GUI")
print("📊 Hidden Lists Loaded:")
print("   • Accessories: " .. #finalHiddenLists.Accessories)
print("   • Secrets: " .. #finalHiddenLists.Secrets)
print("   • Crates: " .. #finalHiddenLists.Crates)
print("   • Pets: " .. #finalHiddenLists.Pets)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
