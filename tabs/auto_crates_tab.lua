-- tabs/auto_crates_tab.lua
-- Auto Open Crates Tab - ปรับปรุง UI (การ์ดเล็กลง, Toggle Select, Start/Stop)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaListener = Knit.GetController("ReplicaListener")

local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local AutoCratesTab = {}
AutoCratesTab.__index = AutoCratesTab

function AutoCratesTab.new(deps)
    local self = setmetatable({}, AutoCratesTab)
    
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    self.InfoLabel = deps.InfoLabel
    
    self.Container = nil
    self.SelectedCrates = {}
    self.CrateCards = {}
    self.IsProcessing = false
    self.ShouldStop = false
    self.LockOverlay = nil -- ✅ สำหรับ Lock UI
    
    return self
end

function AutoCratesTab:Init(parent)
    local THEME = self.Config.THEME
    
    local header = Instance.new("Frame", parent)
    header.Size = UDim2.new(1, 0, 0, 88)
    header.BackgroundTransparency = 1
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "🎁 Auto Open Crates",
        Size = UDim2.new(1, -8, 0, 24),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Select crates and open them automatically (1-8 per batch)",
        Size = UDim2.new(1, -8, 0, 16),
        Position = UDim2.new(0, 8, 0, 24),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local btnContainer = Instance.new("Frame", header)
    btnContainer.Size = UDim2.new(1, -8, 0, 32)
    btnContainer.Position = UDim2.new(0, 8, 0, 42)
    btnContainer.BackgroundTransparency = 1
    
    local btnLayout = Instance.new("UIListLayout", btnContainer)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 8)
    
    self.SelectAllBtn = self.UIFactory.CreateButton({
        Parent = btnContainer,
        Text = "✓ SELECT ALL",
        Size = UDim2.new(0, 140, 0, 32),
        BgColor = THEME.AccentBlue,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6
    })
    self.UIFactory.AddStroke(self.SelectAllBtn, Color3.fromRGB(140, 160, 255), 1, 0.4)
    
    self.AutoOpenBtn = self.UIFactory.CreateButton({
        Parent = btnContainer,
        Text = "🚀 START OPEN",
        Size = UDim2.new(0, 160, 0, 32),
        BgColor = THEME.AccentGreen,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6
    })
    self.UIFactory.AddStroke(self.AutoOpenBtn, Color3.fromRGB(100, 255, 150), 2, 0.3)
    
    self.SelectAllBtn.MouseButton1Click:Connect(function() self:ToggleSelectAll() end)
    self.AutoOpenBtn.MouseButton1Click:Connect(function() self:ToggleAutoOpen() end)
    
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -92),
        Position = UDim2.new(0, 0, 0, 90)
    })
    
    self.Container.ScrollBarThickness = 4
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Container.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellSize = UDim2.new(0, 90, 0, 100)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    self:RefreshInventory()
    self:UpdateInfoLabel()
    self:UpdateSelectButton()
    
    -- ✅ สร้าง Lock Overlay หลังสุด (ซ่อนไว้ก่อน)
    self.LockOverlay = Instance.new("Frame", parent)
    self.LockOverlay.Name = "LockOverlay"
    self.LockOverlay.Size = UDim2.new(1, 0, 1, -92)
    self.LockOverlay.Position = UDim2.new(0, 0, 0, 90)
    self.LockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.LockOverlay.BackgroundTransparency = 0.6
    self.LockOverlay.BorderSizePixel = 0
    self.LockOverlay.ZIndex = 1000
    self.LockOverlay.Visible = false
    
    local lockLabel = self.UIFactory.CreateLabel({
        Parent = self.LockOverlay,
        Text = "🔒 Processing...\nCannot select/edit while opening",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 16,
        Font = Enum.Font.GothamBold
    })
    lockLabel.ZIndex = 1001
    lockLabel.TextWrapped = true
end

function AutoCratesTab:RefreshInventory()
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    self.CrateCards = {}
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    local inventoryCrates = (playerData and playerData.CratesService and playerData.CratesService.Crates) or {}
    
    local cratesList = {}
    for crateName, amount in pairs(inventoryCrates) do
        if amount > 0 then
            local info = CratesInfo[crateName]
            local image = info and info.Image or "0"
            table.insert(cratesList, {
                Name = crateName,
                Amount = amount,
                Image = image
            })
        end
    end
    
    table.sort(cratesList, function(a, b) return a.Name < b.Name end)
    
    for _, crate in ipairs(cratesList) do
        self:CreateCrateCard(crate)
    end
end

function AutoCratesTab:CreateCrateCard(crate)
    local THEME = self.Config.THEME
    local isSelected = self.SelectedCrates[crate.Name] ~= nil
    
    -- ค่าเริ่มต้น 500 หรือตามที่มี
    local defaultAmount = math.min(500, crate.Amount)
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = crate.Name
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Thickness = isSelected and 2 or 1
    Stroke.Color = isSelected and THEME.AccentGreen or THEME.GlassStroke
    Stroke.Transparency = 0.5
    
    -- Checkbox
    local CheckBox = Instance.new("Frame", Card)
    CheckBox.Size = UDim2.new(0, 16, 0, 16)
    CheckBox.Position = UDim2.new(0, 4, 0, 4)
    CheckBox.BackgroundColor3 = isSelected and THEME.AccentGreen or Color3.fromRGB(30, 30, 35)
    CheckBox.BorderSizePixel = 0
    CheckBox.ZIndex = 15
    
    self.UIFactory.AddCorner(CheckBox, 4)
    
    local cbStroke = Instance.new("UIStroke", CheckBox)
    cbStroke.Color = isSelected and THEME.AccentGreen or THEME.GlassStroke
    cbStroke.Thickness = 1
    cbStroke.Transparency = 0.5
    
    local CheckMark = self.UIFactory.CreateLabel({
        Parent = CheckBox,
        Text = isSelected and "✓" or "",
        Size = UDim2.new(1, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 10,
        Font = Enum.Font.GothamBold
    })
    CheckMark.ZIndex = 16
    
    -- Total Amount (เพิ่ม x และทำสีทึบลง)
    local TotalLabel = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = "x" .. tostring(crate.Amount),
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -44, 0, 2),
        TextColor = Color3.fromRGB(180, 180, 180), -- สีเทาอ่อนลง
        TextSize = 11,
        Font = Enum.Font.GothamBold
    })
    TotalLabel.TextStrokeTransparency = 0.5
    TotalLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TotalLabel.ZIndex = 20
    
    -- Image (ใหญ่ขึ้น ตรงกลางการ์ด)
    local Image = Instance.new("ImageLabel", Card)
    Image.Size = UDim2.new(0, 60, 0, 60)
    Image.Position = UDim2.new(0.5, -30, 0.5, -35)
    Image.BackgroundTransparency = 1
    local imgId = tostring(crate.Image)
    if not imgId:find("rbxassetid://") then imgId = "rbxassetid://" .. imgId end
    Image.Image = imgId
    Image.ScaleType = Enum.ScaleType.Fit
    
    -- Input (ค่าเริ่มต้น 500 หรือน้อยกว่า)
    local InputContainer = Instance.new("Frame", Card)
    InputContainer.Size = UDim2.new(1, -10, 0, 18)
    InputContainer.Position = UDim2.new(0, 5, 1, -22)
    InputContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
    InputContainer.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(InputContainer, 4)
    
    local inputStroke = Instance.new("UIStroke", InputContainer)
    inputStroke.Color = THEME.GlassStroke
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.5
    
    local AmountInput = Instance.new("TextBox", InputContainer)
    AmountInput.Size = UDim2.new(1, -8, 1, -2)
    AmountInput.Position = UDim2.new(0, 4, 0, 1)
    AmountInput.BackgroundTransparency = 1
    AmountInput.Text = tostring(defaultAmount)
    AmountInput.TextColor3 = Color3.fromRGB(255, 255, 255) -- สีขาวเต็ม
    AmountInput.Font = Enum.Font.GothamBold -- เปลี่ยนเป็น Bold
    AmountInput.TextSize = 11 -- ขนาดใหญ่ขึ้นนิด
    AmountInput.ClearTextOnFocus = false
    AmountInput.PlaceholderText = tostring(defaultAmount)
    AmountInput.TextXAlignment = Enum.TextXAlignment.Center
    AmountInput.TextStrokeTransparency = 0.7 -- เพิ่ม stroke ให้เด่นขึ้น
    AmountInput.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    self.Utils.SanitizeNumberInput(AmountInput, crate.Amount, 1)
    
    -- Click Button
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.Size = UDim2.new(1, 0, 0, 85)
    ClickBtn.Position = UDim2.new(0, 0, 0, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 5
    
    ClickBtn.MouseButton1Click:Connect(function()
        local amount = tonumber(AmountInput.Text) or math.min(500, crate.Amount)
        
        if amount <= 0 then
            amount = math.min(500, crate.Amount)
            AmountInput.Text = tostring(amount)
        elseif amount > crate.Amount then
            amount = crate.Amount
            AmountInput.Text = tostring(amount)
        end
        
        if self.SelectedCrates[crate.Name] then
            self.SelectedCrates[crate.Name] = nil
            Stroke.Color = THEME.GlassStroke
            Stroke.Thickness = 1
            CheckBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            CheckMark.Text = ""
            cbStroke.Color = THEME.GlassStroke
        else
            self.SelectedCrates[crate.Name] = amount
            Stroke.Color = THEME.AccentGreen
            Stroke.Thickness = 2
            CheckBox.BackgroundColor3 = THEME.AccentGreen
            CheckMark.Text = "✓"
            cbStroke.Color = THEME.AccentGreen
        end
        
        self:UpdateInfoLabel()
        self:UpdateSelectButton()
    end)
    
    AmountInput:GetPropertyChangedSignal("Text"):Connect(function()
        local amount = tonumber(AmountInput.Text) or 0
        
        if amount > crate.Amount then
            AmountInput.Text = tostring(crate.Amount)
            amount = crate.Amount
        elseif amount < 0 then
            AmountInput.Text = "1"
            amount = 1
        end
        
        if self.SelectedCrates[crate.Name] and amount > 0 then
            self.SelectedCrates[crate.Name] = amount
            self:UpdateInfoLabel()
        end
    end)
    
    self.CrateCards[crate.Name] = {
        CheckBox = CheckBox,
        CheckMark = CheckMark,
        Input = AmountInput,
        Stroke = Stroke,
        CheckBoxStroke = cbStroke,
        MaxAmount = crate.Amount,
        DefaultAmount = defaultAmount
    }
end

function AutoCratesTab:ToggleSelectAll()
    -- ป้องกันการกดเมื่อกำลัง Process
    if self.IsProcessing then return end
    
    if self:AreAllSelected() then
        self:DeselectAll()
    else
        self:SelectAll()
    end
    self:UpdateSelectButton()
end

function AutoCratesTab:AreAllSelected()
    local totalCrates = 0
    local selectedCount = 0
    
    for _, data in pairs(self.CrateCards) do
        totalCrates = totalCrates + 1
        if self.SelectedCrates[_] then
            selectedCount = selectedCount + 1
        end
    end
    
    return totalCrates > 0 and totalCrates == selectedCount
end

function AutoCratesTab:UpdateSelectButton()
    if self:AreAllSelected() then
        self.SelectAllBtn.Text = "✕ UNSELECT ALL"
        self.SelectAllBtn.BackgroundColor3 = self.Config.THEME.BtnDefault
    else
        self.SelectAllBtn.Text = "✓ SELECT ALL"
        self.SelectAllBtn.BackgroundColor3 = self.Config.THEME.AccentBlue
    end
end

function AutoCratesTab:SelectAll()
    for crateName, data in pairs(self.CrateCards) do
        local amount = tonumber(data.Input.Text) or data.DefaultAmount
        if amount > 0 and amount <= data.MaxAmount then
            self.SelectedCrates[crateName] = amount
            data.Stroke.Color = self.Config.THEME.AccentGreen
            data.Stroke.Thickness = 2
            data.CheckBox.BackgroundColor3 = self.Config.THEME.AccentGreen
            data.CheckMark.Text = "✓"
            data.CheckBoxStroke.Color = self.Config.THEME.AccentGreen
        end
    end
    self:UpdateInfoLabel()
end

function AutoCratesTab:DeselectAll()
    self.SelectedCrates = {}
    for _, data in pairs(self.CrateCards) do
        data.Stroke.Color = self.Config.THEME.GlassStroke
        data.Stroke.Thickness = 1
        data.CheckBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        data.CheckMark.Text = ""
        data.CheckBoxStroke.Color = self.Config.THEME.GlassStroke
    end
    self:UpdateInfoLabel()
end

function AutoCratesTab:UpdateInfoLabel()
    if not self.InfoLabel then return end
    
    local count = 0
    local total = 0
    for crateName, amount in pairs(self.SelectedCrates) do
        count = count + 1
        total = total + amount
    end
    
    if count > 0 then
        self.InfoLabel.Text = string.format("📦 Selected: %d types | Total: %d crates", count, total)
        self.InfoLabel.TextColor3 = self.Config.THEME.AccentGreen
    else
        self.InfoLabel.Text = ""
    end
end

function AutoCratesTab:ToggleAutoOpen()
    if self.IsProcessing then
        self.ShouldStop = true
        self.AutoOpenBtn.Text = "⏸️ STOPPING..."
        self.AutoOpenBtn.BackgroundColor3 = self.Config.THEME.Warning
    else
        self:StartAutoOpen()
    end
end

function AutoCratesTab:StartAutoOpen()
    if self.IsProcessing then return end
    
    local selectedList = {}
    for crateName, amount in pairs(self.SelectedCrates) do
        if amount > 0 then
            table.insert(selectedList, {Name = crateName, Amount = amount})
        end
    end
    
    if #selectedList == 0 then
        self.StateManager:SetStatus("⚠️ No crates selected!", self.Config.THEME.Warning, self.StatusLabel)
        return
    end
    
    self.IsProcessing = true
    self.ShouldStop = false
    self.AutoOpenBtn.Text = "🛑 STOP OPEN"
    self.AutoOpenBtn.BackgroundColor3 = self.Config.THEME.Fail
    
    -- ✅ แสดง Lock Overlay
    if self.LockOverlay then
        self.LockOverlay.Visible = true
    end
    
    -- ✅ Disable SELECT ALL button
    self.SelectAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    self.SelectAllBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        self:ProcessCrateOpening(selectedList)
    end)
end

function AutoCratesTab:ProcessCrateOpening(selectedList)
    local THEME = self.Config.THEME
    local CratesService = ReplicatedStorage.Packages.Knit.Services.CratesService
    local UseCrateRemote = CratesService.RF:FindFirstChild("UseCrateItem")
    
    if not UseCrateRemote then
        self.StateManager:SetStatus("❌ Remote not found!", THEME.Fail, self.StatusLabel)
        self:ResetButton()
        return
    end
    
    local totalOpened = 0
    local totalTypes = #selectedList
    
    for typeIndex, crateData in ipairs(selectedList) do
        if self.ShouldStop then
            self.StateManager:SetStatus("⏸️ Stopped by user", THEME.Warning, self.StatusLabel)
            break
        end
        
        local crateName = crateData.Name
        local targetAmount = crateData.Amount
        local opened = 0
        
        -- ดึง Input reference
        local cardData = self.CrateCards[crateName]
        if not cardData then continue end
        
        self.StateManager:SetStatus(
            string.format("🎁 Opening %s... (%d/%d)", crateName, typeIndex, totalTypes),
            THEME.AccentBlue,
            self.StatusLabel
        )
        
        while opened < targetAmount do
            if self.ShouldStop then break end
            
            local remaining = targetAmount - opened
            local batchSize = math.min(8, remaining)
            
            local success, err = pcall(function()
                return UseCrateRemote:InvokeServer(crateName, batchSize)
            end)
            
            if success then
                opened = opened + batchSize
                totalOpened = totalOpened + batchSize
                
                -- ✅ อัพเดท countdown ใน Input
                local remainingAmount = targetAmount - opened
                if cardData.Input then
                    cardData.Input.Text = tostring(remainingAmount)
                end
                
                if self.InfoLabel then
                    self.InfoLabel.Text = string.format(
                        "✅ Opened: %d | %s: %d/%d (Left: %d)",
                        totalOpened,
                        crateName,
                        opened,
                        targetAmount,
                        remainingAmount
                    )
                end
                
                task.wait(1)
            else
                warn("Failed to open " .. crateName .. ": " .. tostring(err))
                self.StateManager:SetStatus(
                    string.format("⚠️ Error on %s: %s", crateName, tostring(err)),
                    THEME.Warning,
                    self.StatusLabel
                )
                break
            end
        end
        
        -- เคลียร์รายการที่เปิดเสร็จแล้ว
        self.SelectedCrates[crateName] = nil
        
        -- ✅ รีเซ็ต Input กลับเป็นค่าเริ่มต้น
        if cardData.Input then
            cardData.Input.Text = "0"
        end
        
        task.wait(0.2)
    end
    
    if self.ShouldStop then
        self.StateManager:SetStatus(
            string.format("⏸️ Stopped! Opened %d crates", totalOpened),
            THEME.Warning,
            self.StatusLabel
        )
    else
        self.StateManager:SetStatus(
            string.format("✅ Done! Opened %d crates total", totalOpened),
            THEME.Success,
            self.StatusLabel
        )
    end
    
    self:ResetButton()
    
    task.wait(1)
    self:RefreshInventory()
    self:UpdateInfoLabel()
    self:UpdateSelectButton()
end

function AutoCratesTab:ResetButton()
    self.IsProcessing = false
    self.ShouldStop = false
    self.AutoOpenBtn.Text = "🚀 START OPEN"
    self.AutoOpenBtn.BackgroundColor3 = self.Config.THEME.AccentGreen
    
    -- ✅ ซ่อน Lock Overlay
    if self.LockOverlay then
        self.LockOverlay.Visible = false
    end
    
    -- ✅ Enable SELECT ALL button กลับ
    self:UpdateSelectButton()
    self.SelectAllBtn.TextColor3 = self.Config.THEME.TextWhite
end

return AutoCratesTab
