-- utils.lua
-- Utility Functions

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Utils = {}

function Utils.IsTradeActive()
    local Windows = LocalPlayer.PlayerGui:FindFirstChild("Windows")
    if not Windows then return false end
    local activeWindows = {"TradingFrame", "AreYouSure", "AreYouSureSecret", "AmountSelector"}
    for _, winName in ipairs(activeWindows) do
        local frame = Windows:FindFirstChild(winName)
        if frame and frame.Visible then return true end
    end
    return false
end

function Utils.CheckIsEquipped(guid, name, category, allData)
    if category == "Secrets" then
        return (allData.MonsterService.EquippedMonster == name)
    end
    if not guid then return false end
    if category == "Pets" then
        for _, eqGuid in pairs(allData.PetsService.EquippedPets or {}) do
            if eqGuid == guid then return true end
        end
    elseif category == "Accessories" then
        for _, eqGuid in pairs(allData.AccessoryService.EquippedAccessories or {}) do
            if eqGuid == guid then return true end
        end
    end
    return false
end

function Utils.GetItemDetails(info, category)
    if type(info) ~= "table" then return "" end
    local details = ""
    if category == "Pets" then
        local evo = tonumber(info.Evolution)
        if evo and evo > 0 then details = details .. " " .. string.rep("⭐", evo) end
        if info.Level then details = details .. " Lv." .. info.Level end
    elseif category == "Accessories" then
        if info.Scroll and info.Scroll.Name then
            details = details .. " [" .. info.Scroll.Name .. "]"
        end
    end
    if info.Shiny or info.Golden then details = details .. " [✨]" end
    return details
end

function Utils.SanitizeNumberInput(textBox, maxValue, minValue)
    local connection
    connection = textBox:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = textBox.Text
        if txt == "" then return end
        local numStr = txt:gsub("%D", "")
        if numStr == "" then
            textBox.Text = tostring(minValue or 1)
            return
        end
        if txt ~= numStr then
            textBox.Text = numStr
            return
        end
        local n = tonumber(numStr)
        if n then
            if minValue and n < minValue then
                textBox.Text = tostring(minValue)
                return
            end
            if maxValue and n > maxValue then
                textBox.Text = tostring(maxValue)
                return
            end
        end
    end)
    return connection
end

-- ✨ NEW: ดึง Hidden Lists จากเกมโดยอัตโนมัติ (with Safety)
function Utils.ExtractHiddenLists()
    local hiddenLists = {
        Accessories = {},
        Pets = {},
        Secrets = {},
        Crates = {}
    }
    
    -- ⏳ รอให้เกมโหลดเสร็จก่อน
    local maxWaitTime = 10
    local startTime = tick()
    
    while not LocalPlayer.PlayerScripts:FindFirstChild("Controllers") do
        if tick() - startTime > maxWaitTime then
            warn("⚠️ Controllers not loaded after " .. maxWaitTime .. " seconds")
            return hiddenLists
        end
        task.wait(0.5)
    end
    
    task.wait(1) -- รอเพิ่มเติมให้แน่ใจว่าโหลดเสร็จ
    
    local success, err = pcall(function()
        local Controllers = LocalPlayer.PlayerScripts:FindFirstChild("Controllers")
        if not Controllers then return end
        
        local TradeController = Controllers:FindFirstChild("TradeController")
        if not TradeController then return end
        
        local Tradeables = TradeController:FindFirstChild("Tradeables")
        if not Tradeables then return end
        
        -- 🔍 แยก function ตรวจสอบแต่ละประเภท
        local function SafeExtractList(moduleName, keywords, minLength)
            minLength = minLength or 3
            local module = Tradeables:FindFirstChild(moduleName)
            if not module then return {} end
            
            local loadSuccess, moduleScript = pcall(function()
                return require(module)
            end)
            
            if not loadSuccess then 
                warn("⚠️ Failed to require " .. moduleName)
                return {} 
            end
            
            if not moduleScript.Update then return {} end
            
            if not debug or not debug.getupvalues then 
                warn("⚠️ debug.getupvalues not available")
                return {} 
            end
            
            local upvalSuccess, upvalues = pcall(function()
                return debug.getupvalues(moduleScript.Update)
            end)
            
            if not upvalSuccess then return {} end
            
            for _, v in pairs(upvalues) do
                if type(v) == "table" and #v >= minLength then
                    -- ตรวจสอบว่ามี keyword ที่เราต้องการ
                    local matchCount = 0
                    for i = 1, math.min(#v, 5) do
                        if type(v[i]) == "string" then
                            for _, keyword in ipairs(keywords) do
                                if v[i]:find(keyword) then
                                    matchCount = matchCount + 1
                                    break
                                end
                            end
                        end
                    end
                    
                    -- ถ้ามี keyword ตรงอย่างน้อย 2 ตัว = น่าจะใช่
                    if matchCount >= 2 then
                        return v
                    end
                end
            end
            
            return {}
        end
        
        -- 🎯 ดึงแต่ละประเภท
        hiddenLists.Accessories = SafeExtractList("Accessories", {"Ghost", "Pumpkin", "Tri"}, 3)
        hiddenLists.Crates = SafeExtractList("Crates", {"Crate", "Spooky", "Perfect"}, 1)
        hiddenLists.Secrets = SafeExtractList("Secrets", {"Bandito", "Sahur", "Tung", "Frappochino"}, 5)
        
        -- Pets อาจไม่มี hidden list หรือมีแบบพิเศษ
        local petsList = SafeExtractList("Pets", {"INDEX", "Spooksy", "Present"}, 3)
        if #petsList > 0 then
            hiddenLists.Pets = petsList
        end
    end)
    
    if not success then
        warn("⚠️ ExtractHiddenLists error:", err)
    end
    
    return hiddenLists
end

return Utils
