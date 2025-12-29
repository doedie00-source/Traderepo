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

-- ✨ NEW: ดึง Hidden Lists จากเกมโดยอัตโนมัติ
function Utils.ExtractHiddenLists()
    local hiddenLists = {
        Accessories = {},
        Pets = {},
        Secrets = {},
        Crates = {}
    }
    
    local success, err = pcall(function()
        local TradeController = LocalPlayer.PlayerScripts.Controllers.TradeController
        
        -- 🔍 หา Accessories Hidden List
        local AccessoriesModule = TradeController.Tradeables:FindFirstChild("Accessories")
        if AccessoriesModule then
            local accScript = require(AccessoriesModule)
            if debug and debug.getupvalues then
                local upvalues = debug.getupvalues(accScript.Update)
                for _, v in pairs(upvalues) do
                    if type(v) == "table" and #v > 0 and type(v[1]) == "string" then
                        -- ตรวจสอบว่าเป็น accessory names (มักจะมี "Ghost", "Pumpkin" ฯลฯ)
                        if v[1]:find("Ghost") or v[1]:find("Pumpkin") or v[1]:find("Tri") then
                            hiddenLists.Accessories = v
                            break
                        end
                    end
                end
            end
        end
        
        -- 🔍 หา Crates Hidden List
        local CratesModule = TradeController.Tradeables:FindFirstChild("Crates")
        if CratesModule then
            local crateScript = require(CratesModule)
            if debug and debug.getupvalues then
                local upvalues = debug.getupvalues(crateScript.Update)
                for _, v in pairs(upvalues) do
                    if type(v) == "table" and #v > 0 and type(v[1]) == "string" then
                        -- ตรวจสอบว่าเป็น crate names (มักจะมี "Crate" ในชื่อ)
                        if v[1]:find("Crate") then
                            hiddenLists.Crates = v
                            break
                        end
                    end
                end
            end
        end
        
        -- 🔍 หา Secrets Hidden List
        local SecretsModule = TradeController.Tradeables:FindFirstChild("Secrets")
        if SecretsModule then
            local secretScript = require(SecretsModule)
            if debug and debug.getupvalues then
                local upvalues = debug.getupvalues(secretScript.Update)
                for _, v in pairs(upvalues) do
                    if type(v) == "table" and #v > 0 and type(v[1]) == "string" then
                        -- ตรวจสอบว่าเป็น secret names (มักจะมีชื่อยาวๆ แปลกๆ)
                        if #v >= 5 and (v[1]:find("Bandito") or v[1]:find("Sahur") or v[1]:find("Tung")) then
                            hiddenLists.Secrets = v
                            break
                        end
                    end
                end
            end
        end
        
        -- 🔍 หา Pets Hidden List (ถ้ามี)
        local PetsModule = TradeController.Tradeables:FindFirstChild("Pets")
        if PetsModule then
            local petScript = require(PetsModule)
            if debug and debug.getupvalues then
                local upvalues = debug.getupvalues(petScript.Update)
                for _, v in pairs(upvalues) do
                    if type(v) == "table" and #v > 0 and type(v[1]) == "string" then
                        -- ตรวจสอบว่าเป็น pet names ที่ซ่อน
                        if v[1]:find("I.N.D.E.X") or v[1]:find("Spooksy") or v[1]:find("Present") then
                            hiddenLists.Pets = v
                            break
                        end
                    end
                end
            end
        end
    end)
    
    if not success then
        warn("⚠️ Failed to extract hidden lists:", err)
    end
    
    return hiddenLists
end

return Utils
