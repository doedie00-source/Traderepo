-- state_manager.lua
-- State Manager

local StateManager = {
    Config = nil, -- ตั้งค่าจาก main
    currentMainTab = "Players",
    currentDupeTab = "Items",
    itemsInTrade = {},
    selectedCrates = {}, 
    selectedPets = {}, 
    playerButtons = {},
    statusResetTask = nil,
    inputConnection = nil,
}

function StateManager:SetStatus(text, color, statusLabel)
    local Config = self.Config
    local THEME = Config.THEME
    local CONFIG = Config.CONFIG
    
    if self.statusResetTask then task.cancel(self.statusResetTask) end
    
    -- ✨ เพิ่ม Icon ตามสถานะ
    local icon = "🟢"
    if color == THEME.Success then
        icon = "✅"
    elseif color == THEME.Fail then
        icon = "❌"
    elseif color == THEME.Warning then
        icon = "⚠️"
    elseif color == THEME.AccentBlue or color == THEME.AccentPurple or color == THEME.BtnDupe then
        icon = "🔄"
    elseif color == THEME.PlayerBtn then
        icon = "🚀"
    end
    
    -- อัพเดทข้อความพร้อม icon
    statusLabel.Text = icon .. " " .. text
    statusLabel.TextColor3 = color or THEME.TextGray
    
    -- Reset หลังจากผ่านไประยะเวลา
    self.statusResetTask = task.delay(CONFIG.STATUS_RESET_DELAY, function()
        statusLabel.Text = "🟢 Ready"
        statusLabel.TextColor3 = THEME.TextGray
    end)
end

function StateManager:ResetTrade()
    self.itemsInTrade = {}
    self.selectedCrates = {}
    self.selectedPets = {} 
end

function StateManager:AddToTrade(key, itemData)
    if not self.itemsInTrade[key] then
        self.itemsInTrade[key] = {
            Name = itemData.Name, Amount = 0, Guid = itemData.Guid,
            Service = itemData.Service, Category = itemData.Category,
            Type = itemData.Type, RawInfo = itemData.RawInfo
        }
    end
    self.itemsInTrade[key].Amount = self.itemsInTrade[key].Amount + (itemData.Amount or 1)
end

function StateManager:RemoveFromTrade(key)
    self.itemsInTrade[key] = nil
end

function StateManager:IsInTrade(key)
    return self.itemsInTrade[key] ~= nil
end

function StateManager:ToggleCrateSelection(name, amount)
    if self.selectedCrates[name] then
        self.selectedCrates[name] = nil
        return false 
    else
        self.selectedCrates[name] = amount
        return true 
    end
end

function StateManager:TogglePetSelection(uuid)
    if self.selectedPets[uuid] then
        local removedOrder = self.selectedPets[uuid]
        self.selectedPets[uuid] = nil
        for id, order in pairs(self.selectedPets) do
            if type(order) == "number" and order > removedOrder then
                self.selectedPets[id] = order - 1
            end
        end
    else
        local count = 0
        for _, _ in pairs(self.selectedPets) do count = count + 1 end
        self.selectedPets[uuid] = count + 1
    end
end

return StateManager
