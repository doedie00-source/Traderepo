-- tabs/auto_crates_tab.lua
-- Auto Open Crates Tab + Auto Delete Accessories

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaListener = Knit.GetController("ReplicaListener")

local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local AutoCratesTab = {}
AutoCratesTab.__index = AutoCratesTab

-- ⚙️ Auto Delete Configuration
local AUTO_DELETE_CONFIG = {
    MAX_ACCESSORIES = 200,
    SAFE_THRESHOLD = 16,  -- ลบเมื่อเหลือช่องว่าง <= 16
    BATCH_SIZE = 8,       -- เปิดทีละ 8 กล่อง
    EXCEPTION_LIST = {
        ["Tri Ton"] = true,
        ["Meowl Head"] = true,
        ["Ashen Charm"] = true
    }
}

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
    self.LockOverlay = nil
    
    -- ✅ Auto Delete State
    self.AutoDeleteEnabled = false
    self.TrashNamesList = {}  -- รายชื่อ Accessories ที่เป็นขยะ (Item 1-4)
    
    return self
end

function AutoCratesTab:Init(parent)
    local THEME = self.Config.THEME
    
    -- สร้างฐานข้อมูลขยะ
    self:BuildTrashDatabase()
    
    local header = Instance.new("Frame", parent)
    header.Size = UDim2.new(1, 0, 0, 110) -- ปรับความสูงให้กระชับ
    header.BackgroundTransparency = 1
    
    -- Title
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "🎁 Auto Open Crates",
        Size = UDim2.new(1, -12, 0, 24),
        Position = UDim2.new(0, 10, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Select crates to open automatically",
        Size = UDim2.new(1, -12, 0, 16),
        Position = UDim2.new(0, 10, 0, 22),
        TextColor = THEME.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- 🟢 ROW 1: ปุ่มสั่งงาน (จัดให้เต็มความกว้าง)
    local btnContainer1 = Instance.new("Frame", header)
    btnContainer1.Size = UDim2.new(1, -20, 0, 34)
    btnContainer1.Position = UDim2.new(0, 10, 0, 42)
    btnContainer1.BackgroundTransparency = 1
    
    local btnLayout1 = Instance.new("UIListLayout", btnContainer1)
    btnLayout1.FillDirection = Enum.FillDirection.Horizontal
    btnLayout1.Padding = UDim.new(0, 8)
    
    -- ปุ่ม Select All (กว้าง 35%)
    self.SelectAllBtn = self.UIFactory.CreateButton({
        Parent = btnContainer1,
        Text = "SELECT ALL",
        Size = UDim2.new(0.35, -4, 1, 0),
        BgColor = THEME.CardBg,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        CornerRadius = 8
    })
    self.SelectAllBtnStroke = self.UIFactory.AddStroke(self.SelectAllBtn, THEME.AccentBlue, 1.5, 0.4)

    -- ปุ่ม Start Open (กว้าง 65% - ใหญ่กว่า เด่นกว่า)
    self.AutoOpenBtn = self.UIFactory.CreateButton({
        Parent = btnContainer1,
        Text = "🚀 START OPEN",
        Size = UDim2.new(0.65, -4, 1, 0),
        BgColor = THEME.AccentBlue, -- ใช้สีฟ้าให้เด่น
        TextSize = 13,
        Font = Enum.Font.GothamBlack, -- ตัวหนาพิเศษ
        CornerRadius = 8
    })
    self.AutoOpenBtn.BackgroundTransparency = 0.8
    self.AutoOpenBtnStroke = self.UIFactory.AddStroke(self.AutoOpenBtn, THEME.AccentBlue, 1.5, 0)

    -- 🟢 ROW 2: Toggle Switch + Status
    local row2 = Instance.new("Frame", header)
    row2.Size = UDim2.new(1, -20, 0, 26)
    row2.Position = UDim2.new(0, 10, 0, 84)
    row2.BackgroundTransparency = 1
    
    -- สร้างปุ่ม Toggle แบบ Slide (Custom UI)
    self:CreateToggleSwitch(row2)
    
    -- Status Label (ชิดขวา)
    self.AccessoryStatusLabel = self.UIFactory.CreateLabel({
        Parent = row2,
        Text = "Loading...",
        Size = UDim2.new(1, -120, 1, 0), -- เว้นที่ให้ Toggle ทางซ้าย
        Position = UDim2.new(0, 120, 0, 0),
        TextColor = THEME.TextDim,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlign = Enum.TextXAlignment.Right
    })

    -- Events
    self.SelectAllBtn.MouseButton1Click:Connect(function() self:ToggleSelectAll() end)
    self.AutoOpenBtn.MouseButton1Click:Connect(function() self:ToggleAutoOpen() end)
    
    -- Scrolling Container
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -118), -- ปรับ offset ตาม header ใหม่
        Position = UDim2.new(0, 0, 0, 118)
    })
    
    self.Container.ScrollBarThickness = 3
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 10)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellSize = UDim2.new(0, 94, 0, 105) -- ปรับขนาดการ์ดนิดหน่อย
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    self:RefreshInventory()
    self:UpdateInfoLabel()
    self:UpdateSelectButton()
    self:UpdateAccessoryStatus()
    
    -- Lock Overlay
    self.LockOverlay = Instance.new("Frame", parent)
    self.LockOverlay.Name = "LockOverlay"
    self.LockOverlay.Size = UDim2.new(1, 0, 1, -118)
    self.LockOverlay.Position = UDim2.new(0, 0, 0, 118)
    self.LockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.LockOverlay.BackgroundTransparency = 0.5
    self.LockOverlay.Visible = false
    self.LockOverlay.ZIndex = 100
    
    local lockLabel = self.UIFactory.CreateLabel({
        Parent = self.LockOverlay,
        Text = "🔒 OPENING...",
        Size = UDim2.new(1, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 20,
        Font = Enum.Font.GothamBold
    })

    task.spawn(function()
        while self.Container and self.Container.Parent do
            self:UpdateAccessoryStatus()
            task.wait(2)
        end
    end)
end

-- ✅ ฟังก์ชันสร้างปุ่ม Toggle Switch แบบ Slide
function AutoCratesTab:CreateToggleSwitch(parent)
    local THEME = self.Config.THEME
    
    local container = Instance.new("TextButton", parent)
    container.Text = ""
    container.Size = UDim2.new(0, 110, 1, 0)
    container.BackgroundTransparency = 1
    
    -- ข้อความ "Auto Delete"
    local label = Instance.new("TextLabel", container)
    label.Text = "Auto Delete"
    label.Size = UDim2.new(0, 70, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = THEME.TextGray
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlign = Enum.TextXAlignment.Left
    
    -- รางสวิตช์ (Track)
    local track = Instance.new("Frame", container)
    track.Name = "Track"
    track.Size = UDim2.new(0, 40, 0, 20)
    track.Position = UDim2.new(0, 70, 0.5, -10)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 45) -- สีตอนปิด
    track.BorderSizePixel = 0
    
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)
    
    -- ปุ่มวงกลม (Knob)
    local knob = Instance.new("Frame", track)
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8) -- ตำแหน่งซ้าย (ปิด)
    knob.BackgroundColor3 = THEME.TextWhite
    knob.BorderSizePixel = 0
    
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    -- เก็บ UI ไว้ใช้อัพเดททีหลัง
    self.ToggleUI = {
        Track = track,
        Knob = knob,
        Label = label
    }
    
    -- Event กดปุ่ม
    container.MouseButton1Click:Connect(function()
        self:ToggleAutoDelete()
    end)
end

function AutoCratesTab:ToggleAutoDelete()
    if self.IsProcessing then return end
    
    self.AutoDeleteEnabled = not self.AutoDeleteEnabled
    local THEME = self.Config.THEME
    
    -- Animation Values
    local targetPos = self.AutoDeleteEnabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    local targetColor = self.AutoDeleteEnabled and THEME.AccentGreen or Color3.fromRGB(40, 40, 45)
    local targetTextColor = self.AutoDeleteEnabled and THEME.TextWhite or THEME.TextGray
    
    -- เล่น Animation
    if self.ToggleUI then
        TweenService:Create(self.ToggleUI.Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = targetPos}):Play()
        TweenService:Create(self.ToggleUI.Track, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(self.ToggleUI.Label, TweenInfo.new(0.2), {TextColor3 = targetTextColor}):Play()
    end
    
    -- Update Status Text ด้านล่าง
    if self.AutoDeleteEnabled then
        self.StateManager:SetStatus("✅ Auto Delete Enabled", THEME.Success, self.StatusLabel)
    else
        self.StateManager:SetStatus("⚪ Auto Delete Disabled", THEME.TextGray, self.StatusLabel)
    end
end

-- ✅ สร้างฐานข้อมูลขยะจาก CratesInfo (Item 1-4)
function AutoCratesTab:BuildTrashDatabase()
    self.TrashNamesList = {}
    
    for crateName, crateData in pairs(CratesInfo) do
        if crateData.Rewards then
            local r = crateData.Rewards
            
            -- เก็บเฉพาะ Accessory (1-4)
            if r.ItemOne and r.ItemOne.Name then 
                self.TrashNamesList[r.ItemOne.Name] = true 
            end
            if r.ItemTwo and r.ItemTwo.Name then 
                self.TrashNamesList[r.ItemTwo.Name] = true 
            end
            if r.ItemThree and r.ItemThree.Name then 
                self.TrashNamesList[r.ItemThree.Name] = true 
            end
            if r.ItemFour and r.ItemFour.Name then 
                self.TrashNamesList[r.ItemFour.Name] = true 
            end
        end
    end
    
    -- ลบของยกเว้นออกจากรายการ
    for name, _ in pairs(AUTO_DELETE_CONFIG.EXCEPTION_LIST) do
        if self.TrashNamesList[name] then
            self.TrashNamesList[name] = nil
        end
    end
end

-- ✅ ตรวจสอบจำนวน Accessories และคำนวณช่องว่าง
function AutoCratesTab:GetAccessorySpace()
    local replica = ReplicaListener:GetReplica()
    if not replica or not replica.Data then return 0, 0 end
    
    local accessories = replica.Data.AccessoryService.Accessories or {}
    local count = 0
    for _ in pairs(accessories) do count = count + 1 end
    
    local space = AUTO_DELETE_CONFIG.MAX_ACCESSORIES - count
    return count, space
end

function AutoCratesTab:UpdateAccessoryStatus()
    if not self.AccessoryStatusLabel then return end
    
    local count, space = self:GetAccessorySpace()
    local THEME = self.Config.THEME
    
    local color = THEME.TextDim
    if space <= AUTO_DELETE_CONFIG.SAFE_THRESHOLD then
        color = THEME.Fail
    elseif space <= 50 then
        color = THEME.Warning
    else
        color = THEME.AccentGreen
    end
    
    self.AccessoryStatusLabel.Text = string.format(
        "📦 %d/%d (Free: %d)", -- ข้อความสั้นลงให้อ่านง่าย
        count,
        AUTO_DELETE_CONFIG.MAX_ACCESSORIES,
        space
    )
    self.AccessoryStatusLabel.TextColor3 = color
end

-- ✅ Toggle Auto Delete
function AutoCratesTab:ToggleAutoDelete()
    if self.IsProcessing then return end
    
    self.AutoDeleteEnabled = not self.AutoDeleteEnabled
    local THEME = self.Config.THEME
    
    if self.AutoDeleteEnabled then
        self.AutoDeleteBtn.Text = "🗑️ AUTO DELETE: ON"
        self.AutoDeleteBtn.TextColor3 = THEME.AccentGreen
        self.AutoDeleteBtnStroke.Color = THEME.AccentGreen
        self.StateManager:SetStatus("✅ Auto Delete Enabled", THEME.Success, self.StatusLabel)
    else
        self.AutoDeleteBtn.Text = "🗑️ AUTO DELETE: OFF"
        self.AutoDeleteBtn.TextColor3 = THEME.TextGray
        self.AutoDeleteBtnStroke.Color = THEME.GlassStroke
        self.StateManager:SetStatus("⚪ Auto Delete Disabled", THEME.TextGray, self.StatusLabel)
    end
end

-- ✅ ฟังก์ชันลบ Accessories ขยะ
function AutoCratesTab:AutoDeleteAccessories()
    local replica = ReplicaListener:GetReplica()
    if not replica or not replica.Data then return false end
    
    local accessories = replica.Data.AccessoryService.Accessories
    local equippedList = replica.Data.AccessoryService.EquippedAccessories
    
    local equippedSet = {}
    if equippedList then 
        for _, u in pairs(equippedList) do 
            equippedSet[u] = true 
        end 
    end
    
    local toDeleteList = {}
    
    for uuid, item in pairs(accessories) do
        local n = item.Name
        local shouldDelete = false
        
        -- เงื่อนไข:
        -- 1. อยู่ในรายการขยะ (Item 1-4)
        -- 2. ไม่ใช่ของยกเว้น
        -- 3. ไม่ได้ใส่อยู่
        -- 4. ไม่มี Scroll
        
        if self.TrashNamesList[n] 
            and not AUTO_DELETE_CONFIG.EXCEPTION_LIST[n] 
            and not equippedSet[uuid] 
            and not item.Scroll then
            shouldDelete = true
        end

        if shouldDelete then
            table.insert(toDeleteList, uuid)
        end
    end
    
    if #toDeleteList == 0 then return true end
    
    local THEME = self.Config.THEME
    self.StateManager:SetStatus(
        string.format("🗑️ Deleting %d trash accessories...", #toDeleteList),
        THEME.Warning,
        self.StatusLabel
    )
    
    local success, err = pcall(function()
        return ReplicatedStorage.Packages.Knit.Services.AccessoryService.RF.Delete:InvokeServer(toDeleteList)
    end)
    
    if success then
        self.StateManager:SetStatus(
            string.format("✅ Deleted %d accessories!", #toDeleteList),
            THEME.Success,
            self.StatusLabel
        )
        return true
    else
        self.StateManager:SetStatus(
            "❌ Delete failed: " .. tostring(err),
            THEME.Fail,
            self.StatusLabel
        )
        return false
    end
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
    
    local currentSelectedAmount = self.SelectedCrates[crate.Name]
    local defaultAmount = currentSelectedAmount or math.min(500, crate.Amount)
    
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
    
    local TotalLabel = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = "x" .. tostring(crate.Amount),
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -44, 0, 2),
        TextColor = Color3.fromRGB(180, 180, 180),
        TextSize = 11,
        Font = Enum.Font.GothamBold
    })
    TotalLabel.TextStrokeTransparency = 0.5
    TotalLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TotalLabel.ZIndex = 20
    
    local Image = Instance.new("ImageLabel", Card)
    Image.Size = UDim2.new(0, 60, 0, 60)
    Image.Position = UDim2.new(0.5, -30, 0.5, -35)
    Image.BackgroundTransparency = 1
    local imgId = tostring(crate.Image)
    if not imgId:find("rbxassetid://") then imgId = "rbxassetid://" .. imgId end
    Image.Image = imgId
    Image.ScaleType = Enum.ScaleType.Fit
    
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
    AmountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    AmountInput.Font = Enum.Font.GothamBold
    AmountInput.TextSize = 11
    AmountInput.ClearTextOnFocus = false
    AmountInput.PlaceholderText = tostring(defaultAmount)
    AmountInput.TextXAlignment = Enum.TextXAlignment.Center
    AmountInput.TextStrokeTransparency = 0.7
    AmountInput.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    self.Utils.SanitizeNumberInput(AmountInput, crate.Amount, 1)
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.Size = UDim2.new(1, 0, 0, 85)
    ClickBtn.Position = UDim2.new(0, 0, 0, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 5
    
    ClickBtn.MouseButton1Click:Connect(function()
        if self.IsProcessing then return end
        
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
    
    AmountInput.Focused:Connect(function()
        if self.IsProcessing then
            AmountInput:ReleaseFocus()
        end
    end)

    AmountInput:GetPropertyChangedSignal("Text"):Connect(function()
        if self.IsProcessing then return end
        
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
    local THEME = self.Config.THEME
    
    self.SelectAllBtn.BackgroundColor3 = THEME.CardBg 

    if self:AreAllSelected() then
        self.SelectAllBtn.Text = "UNSELECT ALL"
        self.SelectAllBtn.TextColor3 = THEME.Fail or Color3.fromRGB(255, 85, 85)
        
        if self.SelectAllBtnStroke then
            self.SelectAllBtnStroke.Color = THEME.Fail or Color3.fromRGB(255, 85, 85)
            self.SelectAllBtnStroke.Transparency = 0.4
        end
    else
        self.SelectAllBtn.Text = "SELECT ALL"
        self.SelectAllBtn.TextColor3 = THEME.TextWhite
        
        if self.SelectAllBtnStroke then
            self.SelectAllBtnStroke.Color = THEME.AccentBlue
            self.SelectAllBtnStroke.Transparency = 0.4
        end
    end

    if self.IsProcessing then
        self.SelectAllBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        self.SelectAllBtn.TextTransparency = 0.6
        self.SelectAllBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        if self.SelectAllBtnStroke then
            self.SelectAllBtnStroke.Color = Color3.fromRGB(80, 80, 80)
            self.SelectAllBtnStroke.Transparency = 0.8
        end
    else
        self.SelectAllBtn.TextTransparency = 0
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
    self:UpdateSelectButton()
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
    self:UpdateSelectButton()
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
        self.AutoOpenBtn.Text = "STOPPING..."
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
    self.AutoOpenBtn.Text = "STOP OPEN"
    self.AutoOpenBtn.TextColor3 = self.Config.THEME.Fail
    if self.AutoOpenBtnStroke then
        self.AutoOpenBtnStroke.Color = self.Config.THEME.Fail
    end
    if self.LockOverlay then
        self.LockOverlay.Visible = true
    end
    
    self.SelectAllBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    self.SelectAllBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        self:ProcessCrateOpening(selectedList)
    end)
end

-- ✅ ฟังก์ชันเปิดกล่องพร้อม Auto Delete
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
        
        local cardData = self.CrateCards[crateName]
        if not cardData then continue end
        
        self.StateManager:SetStatus(
            string.format("🎁 Opening %s... (%d/%d)", crateName, typeIndex, totalTypes),
            THEME.AccentBlue,
            self.StatusLabel
        )
        
        while opened < targetAmount do
            if self.ShouldStop then break end
            
            -- ✅ ตรวจสอบช่องว่าง Accessories ก่อนเปิด
            local count, space = self:GetAccessorySpace()
            self:UpdateAccessoryStatus()
            
            -- ✅ ถ้าช่องว่าง <= 16 และเปิด Auto Delete
            if space <= AUTO_DELETE_CONFIG.SAFE_THRESHOLD then
                if self.AutoDeleteEnabled then
                    self.StateManager:SetStatus(
                        string.format("🗑️ Space low (%d) - Deleting...", space),
                        THEME.Warning,
                        self.StatusLabel
                    )
                    
                    local deleteSuccess = self:AutoDeleteAccessories()
                    if deleteSuccess then
                        task.wait(0.5)
                        count, space = self:GetAccessorySpace()
                        self:UpdateAccessoryStatus()
                    else
                        -- ลบไม่สำเร็จ หยุดเปิด
                        self.StateManager:SetStatus("❌ Delete failed - Stopping", THEME.Fail, self.StatusLabel)
                        self.ShouldStop = true
                        break
                    end
                else
                    -- ไม่ได้เปิด Auto Delete และของเต็ม หยุดเปิด
                    self.StateManager:SetStatus(
                        string.format("⚠️ Inventory full (%d/%d) - Stopping", count, AUTO_DELETE_CONFIG.MAX_ACCESSORIES),
                        THEME.Fail,
                        self.StatusLabel
                    )
                    self.ShouldStop = true
                    break
                end
            end
            
            -- ✅ ตรวจสอบซ้ำหลังลบ ว่ายังมีที่ว่างพอเปิดต่อไหม
            count, space = self:GetAccessorySpace()
            if space < AUTO_DELETE_CONFIG.BATCH_SIZE then
                self.StateManager:SetStatus(
                    string.format("⚠️ Not enough space (%d) - Stopping", space),
                    THEME.Fail,
                    self.StatusLabel
                )
                self.ShouldStop = true
                break
            end
            
            local remaining = targetAmount - opened
            local batchSize = math.min(AUTO_DELETE_CONFIG.BATCH_SIZE, remaining)
            
            local success, err = pcall(function()
                return UseCrateRemote:InvokeServer(crateName, batchSize)
            end)
            
            if success then
                opened = opened + batchSize
                totalOpened = totalOpened + batchSize
                
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
                
                local randomWait = math.random(100, 220) / 100 
                task.wait(randomWait)
            else
                warn("Failed to open " .. crateName .. ": " .. tostring(err))
                self.StateManager:SetStatus(
                    string.format("⚠️ Error on %s: %s", crateName, tostring(err)),
                    THEME.Warning,
                    self.StatusLabel
                )
                task.wait(2)
                break
            end
        end
        
        local remaining = targetAmount - opened

        if remaining > 0 then
            self.SelectedCrates[crateName] = remaining
            
            if cardData.Input then
                cardData.Input.Text = tostring(remaining)
            end
        else
            self.SelectedCrates[crateName] = nil
            
            local THEME = self.Config.THEME
            if cardData.Stroke then 
                cardData.Stroke.Color = THEME.GlassStroke 
                cardData.Stroke.Thickness = 1
            end
            if cardData.CheckBox then 
                cardData.CheckBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35) 
            end
            if cardData.CheckMark then 
                cardData.CheckMark.Text = "" 
            end
            if cardData.CheckBoxStroke then 
                cardData.CheckBoxStroke.Color = THEME.GlassStroke 
            end
            
            if cardData.Input then
                cardData.Input.Text = tostring(cardData.DefaultAmount or 1)
            end
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
    self:UpdateAccessoryStatus()
end

function AutoCratesTab:ResetButton()
    self.IsProcessing = false
    self.ShouldStop = false
    local THEME = self.Config.THEME
    
    self.AutoOpenBtn.Text = "START OPEN"
    self.AutoOpenBtn.TextColor3 = THEME.TextWhite
    self.AutoOpenBtn.BackgroundColor3 = THEME.AccentBlue
    
    if self.AutoOpenBtnStroke then
        self.AutoOpenBtnStroke.Color = THEME.AccentBlue
    end
    
    if self.LockOverlay then
        self.LockOverlay.Visible = false
    end
    
    self:UpdateSelectButton()
end

return AutoCratesTab
