-- tabs/dupe_tab.lua
-- Dupe Tab Module (Items, Crates, Pets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaListener = Knit.GetController("ReplicaListener")

-- Load Game Info
local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local SuccessLoadPets, PetsInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.PetsInfo) 
end)
if not SuccessLoadPets then PetsInfo = {} end

local DupeTab = {}
DupeTab.__index = DupeTab

function DupeTab.new(deps)
    local self = setmetatable({}, DupeTab)
    
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    self.ScreenGui = deps.ScreenGui
    
    self.Container = nil
    self.SubTabButtons = {}
    self.CurrentSubTab = "Items"
    self.ActionBar = nil
    self.TooltipRef = nil
    
    return self
end

function DupeTab:Init(parent)
    local THEME = self.Config.THEME
    
    -- Header
    local header = Instance.new("Frame", parent)
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 78)
    header.BackgroundTransparency = 1
    
    local title = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "✨ Magic Dupe System",
        Size = UDim2.new(1, 0, 0, 26),
        TextColor = THEME.TextWhite,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local subtitle = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Dupe items, crates, and pets using trade exploit",
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 26),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Sub-tabs
    local tabsContainer = Instance.new("Frame", header)
    tabsContainer.Size = UDim2.new(1, 0, 0, 32)
    tabsContainer.Position = UDim2.new(0, 0, 0, 46)
    tabsContainer.BackgroundTransparency = 1
    
    local tabsLayout = Instance.new("UIListLayout", tabsContainer)
    tabsLayout.FillDirection = Enum.FillDirection.Horizontal
    tabsLayout.Padding = UDim.new(0, 6)
    
    self:CreateSubTab(tabsContainer, "Items", "📦 Items")
    self:CreateSubTab(tabsContainer, "Crates", "🎁 Crates")
    self:CreateSubTab(tabsContainer, "Pets", "🐾 Pets")
    
    -- Content Container
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -126),
        Position = UDim2.new(0, 0, 0, 82)
    })
    
    -- Action Bar
    self:CreateActionBar(parent)
    
    -- Warning Box (for Items tab)
    self:CreateWarningBox(parent)
    
    -- Load First Tab
    self:SwitchSubTab("Items")
end

function DupeTab:CreateSubTab(parent, name, text)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Size = UDim2.new(0, 95, 0, 32),
        BgColor = THEME.BtnDefault,
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        OnClick = function()
            self:SwitchSubTab(name)
        end
    })
    
    self.SubTabButtons[name] = btn
end

function DupeTab:SwitchSubTab(name)
    local THEME = self.Config.THEME
    
    self.CurrentSubTab = name
    self.StateManager.currentDupeTab = name
    self.StateManager.selectedPets = {}
    self.StateManager.selectedCrates = {}
    
    -- Update Buttons
    for tabName, btn in pairs(self.SubTabButtons) do
        local isSelected = (tabName == name)
        btn.BackgroundColor3 = isSelected and THEME.AccentBlue or THEME.BtnDefault
        btn.TextColor3 = isSelected and THEME.TextWhite or THEME.TextGray
    end
    
    self:RefreshInventory()
end

function DupeTab:CreateActionBar(parent)
    local THEME = self.Config.THEME
    
    self.ActionBar = Instance.new("Frame", parent)
    self.ActionBar.Name = "ActionBar"
    self.ActionBar.Size = UDim2.new(1, 0, 0, 42)
    self.ActionBar.Position = UDim2.new(0, 0, 1, -42)
    self.ActionBar.BackgroundColor3 = THEME.GlassBg
    self.ActionBar.BackgroundTransparency = THEME.GlassTransparency
    self.ActionBar.BorderSizePixel = 0
    self.ActionBar.Visible = false
    
    self.UIFactory.AddCorner(self.ActionBar, 8)
    self.UIFactory.AddStroke(self.ActionBar, THEME.GlassStroke, 1, 0.7)
    
    -- Pet Actions
    self.BtnDeletePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(0, 6, 0.5, -15),
        Text = "🗑️ DELETE",
        BgColor = THEME.Fail,
        TextSize = 10,
        Parent = self.ActionBar,
        OnClick = function() self:OnDeletePets() end
    })
    
    self.BtnEvoPet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 115, 0, 30),
        Position = UDim2.new(0.5, -57.5, 0.5, -15),
        Text = "EVOLVE",
        BgColor = THEME.BtnDefault,
        TextSize = 10,
        Parent = self.ActionBar,
        OnClick = function() self:OnEvolvePets() end
    })
    
    self.BtnDupePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(1, -86, 0.5, -15),
        Text = "✨ DUPE",
        BgColor = THEME.BtnDupe,
        TextSize = 10,
        Parent = self.ActionBar,
        OnClick = function() self:OnDupePets() end
    })
    
    -- Crate Actions
    self.BtnAddAll1k = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 125, 0, 30),
        Position = UDim2.new(1, -131, 0.5, -15),
        Text = "ADD 1K ALL",
        BgColor = THEME.AccentGreen,
        TextSize = 10,
        Parent = self.ActionBar
    })
    self.UIFactory.AddStroke(self.BtnAddAll1k, Color3.new(1,1,1), 1, 0.6)
end

function DupeTab:CreateWarningBox(parent)
    local THEME = self.Config.THEME
    
    self.WarningBox = Instance.new("Frame", parent)
    self.WarningBox.Name = "WarningBox"
    self.WarningBox.Size = UDim2.new(1, 0, 0, 52)
    self.WarningBox.Position = UDim2.new(0, 0, 1, -98)
    self.WarningBox.BackgroundColor3 = Color3.fromRGB(35, 28, 22)
    self.WarningBox.BackgroundTransparency = 0.2
    self.WarningBox.BorderSizePixel = 0
    self.WarningBox.Visible = false
    
    self.UIFactory.AddCorner(self.WarningBox, 8)
    self.UIFactory.AddStroke(self.WarningBox, THEME.Warning, 1.5, 0.4)
    
    local icon = self.UIFactory.CreateLabel({
        Parent = self.WarningBox,
        Text = "⚠️",
        Size = UDim2.new(0, 35, 1, 0),
        TextSize = 20,
        Font = Enum.Font.GothamBold
    })
    
    local text = self.UIFactory.CreateLabel({
        Parent = self.WarningBox,
        Text = "WARNING: Do not exceed limits!\nSCROLLS: ~150 | TICKETS: 10k | POTIONS: 2k\nRisk of ban if hoarding excessive amounts.",
        Size = UDim2.new(1, -40, 1, -8),
        Position = UDim2.new(0, 38, 0, 4),
        TextColor = THEME.Warning,
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    text.TextWrapped = true
end

function DupeTab:RefreshInventory()
    -- Clear container
    for _, child in pairs(self.Container:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    
    -- Hide/Show Action Bar and Warning
    self.ActionBar.Visible = (self.CurrentSubTab == "Pets" or self.CurrentSubTab == "Crates")
    self.WarningBox.Visible = (self.CurrentSubTab == "Items")
    
    -- Update Container Size
    if self.CurrentSubTab == "Items" then
        self.Container.Size = UDim2.new(1, 0, 1, -186)
    elseif self.CurrentSubTab == "Pets" or self.CurrentSubTab == "Crates" then
        self.Container.Size = UDim2.new(1, 0, 1, -168)
    end
    
    -- Render Content
    if self.CurrentSubTab == "Items" then
        self:RenderItemDupeGrid()
    elseif self.CurrentSubTab == "Crates" then
        self:RenderCrateGrid()
    elseif self.CurrentSubTab == "Pets" then
        self:RenderPetDupeGrid()
    end
end

-- ============================
-- ITEMS TAB RENDERING
-- ============================
function DupeTab:RenderItemDupeGrid()
    local THEME = self.Config.THEME
    local DUPE_RECIPES = self.Config.DUPE_RECIPES
    
    self.Container.ScrollBarThickness = 0
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.CellSize = UDim2.new(0, 92, 0, 115)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    
    local recipes = DUPE_RECIPES.Items or {}
    local playerData = self.InventoryManager.GetPlayerData()
    
    for _, recipe in ipairs(recipes) do
        self:CreateItemCard(recipe, playerData)
    end
end

function DupeTab:CreateItemCard(recipe, playerData)
    local THEME = self.Config.THEME
    local serviceName = recipe.Service
    
    local isOwned = false
    if playerData and playerData.ItemsService and playerData.ItemsService.Inventory then
        local inv = playerData.ItemsService.Inventory[serviceName]
        if inv then
            local amt = inv[tostring(recipe.Tier)] or inv[tonumber(recipe.Tier)] or 0
            if amt > 0 then isOwned = true end
        end
    end
    
    local totalNeeded, foundCount = 0, 0
    local isPotion = (serviceName == "Strawberry" or serviceName:find("Potion"))
    
    if isPotion then
        totalNeeded = #recipe.RequiredTiers
        for _, tier in ipairs(recipe.RequiredTiers) do
            if self.InventoryManager.HasItem(serviceName, tier, playerData) then
                foundCount = foundCount + 1
            end
        end
    else
        totalNeeded = 2
        for _, tier in ipairs(recipe.RequiredTiers) do
            local tNum = tonumber(tier)
            if tNum > 2 and tNum ~= tonumber(recipe.Tier) then
                if self.InventoryManager.HasItem(serviceName, tNum, playerData) then
                    foundCount = foundCount + 1
                end
            end
        end
    end
    
    local isReady = (not isOwned) and (foundCount >= totalNeeded)
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = recipe.Name
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    local strokeColor = THEME.GlassStroke
    local statusText = ""
    
    if isOwned then
        strokeColor = THEME.Fail
        statusText = "<font color='#ff5555' size='9'>(OWNED)</font>"
    elseif isReady then
        strokeColor = THEME.DupeReady
        statusText = "<font color='#00ffaa' size='10'>✓ READY</font>"
    else
        strokeColor = THEME.Warning
        statusText = string.format("<font color='#ffcc33' size='9'>%d/%d</font>", foundCount, totalNeeded)
    end
    
    self.UIFactory.AddStroke(Card, strokeColor, 1.5, 0.4)
    
    local Image = Instance.new("ImageLabel", Card)
    Image.BackgroundTransparency = 1
    Image.Position = UDim2.new(0.5, -32, 0, 10)
    Image.Size = UDim2.new(0, 64, 0, 64)
    Image.Image = "rbxassetid://" .. (recipe.Image or "0")
    Image.ScaleType = Enum.ScaleType.Fit
    if isOwned then Image.ImageColor3 = Color3.fromRGB(80, 80, 80) end
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 4, 0, 78)
    NameLbl.Size = UDim2.new(1, -8, 0, 48)
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 10
    NameLbl.TextWrapped = true
    NameLbl.TextYAlignment = Enum.TextYAlignment.Top
    NameLbl.RichText = true
    NameLbl.Text = recipe.Name .. "\n" .. statusText
    NameLbl.TextColor3 = isOwned and Color3.fromRGB(120, 120, 120) or THEME.TextWhite
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.Text = ""
    
    ClickBtn.MouseButton1Click:Connect(function()
        self:OnItemCardClick(recipe, isOwned, isReady, foundCount, totalNeeded, serviceName)
    end)
end

function DupeTab:OnItemCardClick(recipe, isOwned, isReady, foundCount, totalNeeded, serviceName)
    local THEME = self.Config.THEME
    
    if self.TradeManager.IsProcessing then return end
    
    if not self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    if isOwned then
        self.StateManager:SetStatus("❌ Already Owned!", THEME.Fail, self.StatusLabel)
        return
    end
    
    if not isReady then
        self.StateManager:SetStatus(string.format("⚠️ Missing Ingredients (%d/%d)", foundCount, totalNeeded), THEME.Warning, self.StatusLabel)
        return
    end
    
    local startVal, currentMax = 99, 100
    if serviceName == "Scrolls" then
        startVal, currentMax = 99, 120
    elseif serviceName == "Tickets" then
        startVal, currentMax = 5000, 10000
    else
        startVal, currentMax = 500, 1000
    end
    
    self:ShowQuantityPopup({Default = startVal, Max = currentMax}, function(quantity)
        self.TradeManager.ExecuteMagicDupe(recipe, self.StatusLabel, quantity, self.StateManager, self.Utils, self.InventoryManager)
    end)
end

-- ============================
-- CRATES TAB RENDERING
-- ============================
function DupeTab:RenderCrateGrid()
    local THEME = self.Config.THEME
    
    self.Container.ScrollBarThickness = 0
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.CellSize = UDim2.new(0, 88, 0, 102)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    local inventoryCrates = (playerData and playerData.CratesService and playerData.CratesService.Crates) or {}
    
    local cratesList = {}
    for internalId, info in pairs(CratesInfo) do
        if type(info) == "table" then
            local displayName = info.Name or internalId
            if displayName ~= "KeKa Crate" then
                table.insert(cratesList, {
                    DisplayName = displayName,
                    InternalID = internalId,
                    Image = info.Image or "0"
                })
            end
        end
    end
    table.sort(cratesList, function(a, b) return a.DisplayName < b.DisplayName end)
    
    -- Add All Button Logic
    if self.AddAllConn then self.AddAllConn:Disconnect() end
    self.AddAllConn = self.BtnAddAll1k.MouseButton1Click:Connect(function()
        self:OnAddAllCrates(cratesList, inventoryCrates)
    end)
    
    for _, crate in ipairs(cratesList) do
        self:CreateCrateCard(crate, inventoryCrates)
    end
end

function DupeTab:CreateCrateCard(crate, inventoryCrates)
    local THEME = self.Config.THEME
    
    local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
    local isOwnedInSystem = (amountInInv ~= nil)
    local isSelected = self.StateManager.selectedCrates[crate.DisplayName] ~= nil
    local isInTrade = self.StateManager:IsInTrade(crate.DisplayName)
    local shouldHighlight = isSelected or isInTrade
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = crate.DisplayName
    Card.BackgroundColor3 = isOwnedInSystem and Color3.fromRGB(35, 25, 25) or THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    local strokeColor = THEME.GlassStroke
    if isOwnedInSystem then
        strokeColor = THEME.Fail
    elseif shouldHighlight then
        strokeColor = THEME.CrateSelected
    end
    self.UIFactory.AddStroke(Card, strokeColor, 1.5, isOwnedInSystem and 0.3 or 0.5)
    
    local Image = Instance.new("ImageLabel", Card)
    Image.BackgroundTransparency = 1
    Image.Position = UDim2.new(0.5, -30, 0, 10)
    Image.Size = UDim2.new(0, 60, 0, 60)
    Image.ImageTransparency = isOwnedInSystem and 0.6 or 0
    local imgId = tostring(crate.Image)
    if not imgId:find("rbxassetid://") then imgId = "rbxassetid://" .. imgId end
    Image.Image = imgId
    Image.ScaleType = Enum.ScaleType.Fit
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 4, 0, 72)
    NameLbl.Size = UDim2.new(1, -8, 0, 38)
    NameLbl.Font = Enum.Font.GothamMedium
    NameLbl.TextSize = 9
    NameLbl.TextWrapped = true
    NameLbl.TextYAlignment = Enum.TextYAlignment.Top
    NameLbl.RichText = true
    
    if shouldHighlight then
        local amt = self.StateManager.selectedCrates[crate.DisplayName] or
                    (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 0
        NameLbl.Text = crate.DisplayName .. "\n<font color='#43B581'>[x" .. amt .. "]</font>"
        NameLbl.TextColor3 = THEME.CrateSelected
    elseif isOwnedInSystem then
        NameLbl.Text = crate.DisplayName .. "\n<font color='#888888'>(OWNED)</font>"
        NameLbl.TextColor3 = Color3.fromRGB(120, 120, 120)
    else
        NameLbl.Text = crate.DisplayName
        NameLbl.TextColor3 = THEME.TextWhite
    end
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.Text = ""
    
    ClickBtn.MouseButton1Click:Connect(function()
        self:OnCrateCardClick(crate, isOwnedInSystem)
    end)
end

function DupeTab:OnCrateCardClick(crate, isOwnedInSystem)
    local THEME = self.Config.THEME
    
    if not self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    if isOwnedInSystem then
        self.StateManager:SetStatus("🚫 Locked: You already own this crate", THEME.Fail, self.StatusLabel)
        return
    end
    
    local isAlreadyAdded = self.StateManager.selectedCrates[crate.DisplayName] or self.StateManager:IsInTrade(crate.DisplayName)
    
    if isAlreadyAdded then
        local oldAmount = self.StateManager.selectedCrates[crate.DisplayName] or
                        (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 1000
        self.StateManager:ToggleCrateSelection(crate.DisplayName, nil)
        self.TradeManager.SendTradeSignal("Remove", {
            Name = crate.DisplayName,
            Service = "CratesService",
            Category = "Crates"
        }, oldAmount, self.StatusLabel, self.StateManager, self.Utils)
        self:RefreshInventory()
    else
        self:ShowQuantityPopup({Default = 1000, Max = 9999}, function(qty)
            self.StateManager:ToggleCrateSelection(crate.DisplayName, qty)
            self.TradeManager.SendTradeSignal("Add", {
                Name = crate.DisplayName,
                Service = "CratesService",
                Category = "Crates"
            }, qty, self.StatusLabel, self.StateManager, self.Utils)
            self:RefreshInventory()
        end)
    end
end

function DupeTab:OnAddAllCrates(cratesList, inventoryCrates)
    local THEME = self.Config.THEME
    
    if not self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    self.BtnAddAll1k.Active = false
    self.BtnAddAll1k.Text = "ADDING..."
    self.StateManager:SetStatus("🚀 Adding all crates (1,000 each)...", THEME.AccentBlue, self.StatusLabel)
    
    task.spawn(function()
        local addedCount = 0
        for _, crate in ipairs(cratesList) do
            local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
            if amountInInv == nil then
                self.TradeManager.SendTradeSignal("Add", {
                    Name = crate.DisplayName,
                    Service = "CratesService",
                    Category = "Crates"
                }, 1000, self.StatusLabel, self.StateManager, self.Utils)
                addedCount = addedCount + 1
                task.wait(0.05)
            end
        end
        self.StateManager:SetStatus("✅ Added " .. addedCount .. " types!", THEME.Success, self.StatusLabel)
        self.BtnAddAll1k.Active = true
        self.BtnAddAll1k.Text = "ADD 1K ALL"
        self:RefreshInventory()
    end)
end

-- ============================
-- PETS TAB RENDERING
-- ============================
function DupeTab:RenderPetDupeGrid()
    local THEME = self.Config.THEME
    
    local ALLOWED_PETS = {
        ["Meowrrior"] = true,
        ["Batkin"] = true,
        ["Xmastree"] = true,
        ["Malame"] = true,
        ["Meowl"] = true,
        ["Medus"] = true,
        ["Flame"] = true,
        ["Mega Flame"] = true,
        ["Turbo Flame"] = true,
        ["Ultra Flame"] = true,
        ["I2Pet"] = true
    }
    
    -- Tooltip Setup
    if not self.TooltipRef then
        local tip = Instance.new("TextLabel", self.ScreenGui)
        tip.Name = "GlobalTooltip"
        tip.Size = UDim2.new(0, 250, 0, 30)
        tip.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        tip.TextColor3 = THEME.TextWhite
        tip.TextSize = 11
        tip.Font = Enum.Font.Code
        tip.ZIndex = 300
        tip.Visible = false
        
        self.UIFactory.AddStroke(tip, THEME.AccentPurple, 1, 0.5)
        self.UIFactory.AddCorner(tip, 6)
        self.TooltipRef = tip
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and self.TooltipRef.Visible then
                self.TooltipRef.Position = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y + 15)
            end
        end)
    end
    
    self.Container.ScrollBarThickness = 0
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellSize = UDim2.new(0, 92, 0, 110)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    
    local replica = ReplicaListener:GetReplica()
    local MyPetsData = replica and replica.Data.PetsService and replica.Data.PetsService.Pets
    local rawEquipped = replica and replica.Data.PetsService and replica.Data.PetsService.EquippedPets or {}
    local EquippedUUIDs = {}
    for _, uuid in pairs(rawEquipped) do EquippedUUIDs[uuid] = true end
    
    if not MyPetsData then return end
    
    local sortedPets = {}
    for uuid, data in pairs(MyPetsData) do
        if data.Name and ALLOWED_PETS[data.Name] then
            data.UUID = uuid
            table.insert(sortedPets, data)
        end
    end
    
    table.sort(sortedPets, function(a, b)
        local aEq = EquippedUUIDs[a.UUID] or false
        local bEq = EquippedUUIDs[b.UUID] or false
        if aEq ~= bEq then return aEq end
        local aEvo = a.Evolution or 0
        local bEvo = b.Evolution or 0
        if aEvo ~= bEvo then return aEvo > bEvo end
        return (a.Name or "") < (b.Name or "")
    end)
    
    for _, petData in ipairs(sortedPets) do
        self:CreatePetCard(petData, EquippedUUIDs, replica.Data)
    end
    
    self:UpdateEvoButtonState()
end

function DupeTab:CreatePetCard(petData, EquippedUUIDs, allData)
    local THEME = self.Config.THEME
    
    local uuid = petData.UUID
    local petName = petData.Name or "Unknown"
    local evolution = petData.Evolution or 0
    local isEquipped = EquippedUUIDs[uuid] == true
    local isLocked = isEquipped
    
    local imageId = "rbxassetid://0"
    if PetsInfo[petName] and PetsInfo[petName].Image then
        imageId = "rbxassetid://" .. tostring(PetsInfo[petName].Image)
    end
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = uuid
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Thickness = 2
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Enabled = false
    
    local OrderBadge = Instance.new("TextLabel", Card)
    OrderBadge.Name = "OrderBadge"
    OrderBadge.Size = UDim2.new(0, 26, 0, 26)
    OrderBadge.Position = UDim2.new(1, -30, 0, 4)
    OrderBadge.BackgroundColor3 = THEME.AccentPurple
    OrderBadge.TextColor3 = THEME.TextWhite
    OrderBadge.Font = Enum.Font.GothamBold
    OrderBadge.TextSize = 14
    OrderBadge.Visible = false
    OrderBadge.ZIndex = 10
    OrderBadge.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(OrderBadge, 100)
    self.UIFactory.AddStroke(OrderBadge, THEME.TextWhite, 1, 0.5)
    
    local function UpdateState()
        local orderNum = self.StateManager.selectedPets[uuid]
        local isSelected = (orderNum ~= nil)
        
        if isLocked then
            Stroke.Color = THEME.CardStrokeLocked
            Stroke.Enabled = true
            OrderBadge.Visible = false
        elseif isSelected then
            Stroke.Color = THEME.CardStrokeSelected
            Stroke.Enabled = true
            OrderBadge.Text = tostring(orderNum)
            OrderBadge.Visible = true
        else
            Stroke.Enabled = false
            OrderBadge.Visible = false
        end
    end
    UpdateState()
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 5
    
    ClickBtn.MouseButton1Click:Connect(function()
        if isLocked then return end
        self.StateManager:TogglePetSelection(uuid)
        UpdateState()
        
        for _, otherCard in pairs(self.Container:GetChildren()) do
            if otherCard:IsA("Frame") and otherCard:FindFirstChild("OrderBadge") then
                local otherUUID = otherCard.Name
                local otherOrder = self.StateManager.selectedPets[otherUUID]
                local badge = otherCard.OrderBadge
                local otherStroke = otherCard:FindFirstChild("UIStroke")
                
                if otherOrder then
                    badge.Text = tostring(otherOrder)
                    badge.Visible = true
                    if otherStroke then
                        otherStroke.Enabled = true
                        otherStroke.Color = THEME.CardStrokeSelected
                    end
                else
                    badge.Visible = false
                    if not self.Utils.CheckIsEquipped(otherUUID, nil, "Pets", allData) then
                        if otherStroke then otherStroke.Enabled = false end
                    end
                end
            end
        end
        self:UpdateEvoButtonState()
    end)
    
    if isEquipped then
        local EqTag = Instance.new("TextLabel", Card)
        EqTag.Text = "EQUIP"
        EqTag.Size = UDim2.new(0, 40, 0, 10)
        EqTag.Position = UDim2.new(1, -42, 0, 5)
        EqTag.BackgroundTransparency = 1
        EqTag.TextColor3 = THEME.CardStrokeLocked
        EqTag.Font = Enum.Font.GothamBlack
        EqTag.TextSize = 7
        EqTag.TextXAlignment = Enum.TextXAlignment.Right
        EqTag.ZIndex = 4
    end
    
    if evolution > 0 then
        local StarContainer = Instance.new("Frame", Card)
        StarContainer.Size = UDim2.new(0, 40, 0, 20)
        StarContainer.Position = UDim2.new(0, 4, 0, 4)
        StarContainer.BackgroundTransparency = 1
        StarContainer.ZIndex = 5
        
        local List = Instance.new("UIListLayout", StarContainer)
        List.FillDirection = Enum.FillDirection.Horizontal
        List.Padding = UDim.new(0, -3)
        
        for i = 1, evolution do
            local Star = Instance.new("ImageLabel", StarContainer)
            Star.Size = UDim2.new(0, 14, 0, 14)
            Star.BackgroundTransparency = 1
            Star.Image = "rbxassetid://3926305904"
            Star.ImageRectOffset = Vector2.new(116, 4)
            Star.ImageRectSize = Vector2.new(24, 24)
            Star.ImageColor3 = THEME.StarColor
            Star.ZIndex = 6
        end
    end
    
    local Viewport = Instance.new("ImageLabel", Card)
    Viewport.Size = UDim2.new(0, 68, 0, 68)
    Viewport.Position = UDim2.new(0.5, -34, 0, 18)
    Viewport.BackgroundTransparency = 1
    Viewport.Image = imageId
    Viewport.ScaleType = Enum.ScaleType.Fit
    Viewport.ZIndex = 2
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.Text = petName
    NameLbl.Size = UDim2.new(1, -4, 0, 20)
    NameLbl.Position = UDim2.new(0, 2, 0, 88)
    NameLbl.BackgroundTransparency = 1
    NameLbl.TextColor3 = THEME.TextWhite
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 10
    NameLbl.TextWrapped = true
    
    local shortID = uuid:sub(1, 4) .. ".." .. uuid:sub(#uuid - 3, #uuid)
    local UUIDDisplay = Instance.new("TextLabel", Card)
    UUIDDisplay.Text = shortID
    UUIDDisplay.Size = UDim2.new(1, -8, 0, 16)
    UUIDDisplay.Position = UDim2.new(0, 4, 1, -20)
    UUIDDisplay.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    UUIDDisplay.TextColor3 = THEME.TextWhite
    UUIDDisplay.Font = Enum.Font.Code
    UUIDDisplay.TextSize = 9
    UUIDDisplay.ZIndex = 3
    UUIDDisplay.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(UUIDDisplay, 4)
    self.UIFactory.AddStroke(UUIDDisplay, THEME.GlassStroke, 1, 0.6)
    
    local HoverTrigger = Instance.new("TextButton", UUIDDisplay)
    HoverTrigger.Text = ""
    HoverTrigger.BackgroundTransparency = 1
    HoverTrigger.Size = UDim2.new(1, 0, 1, 0)
    HoverTrigger.ZIndex = 10
    
    HoverTrigger.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(uuid)
            local originalText = shortID
            UUIDDisplay.Text = "COPIED!"
            UUIDDisplay.TextColor3 = THEME.Success
            self.StateManager:SetStatus("✅ Copied UUID to clipboard!", THEME.Success, self.StatusLabel)
            task.delay(1, function()
                if UUIDDisplay and UUIDDisplay.Parent then
                    UUIDDisplay.Text = originalText
                    UUIDDisplay.TextColor3 = THEME.TextWhite
                end
            end)
        else
            self.StateManager:SetStatus("⚠️ Executor doesn't support clipboard", THEME.Warning, self.StatusLabel)
        end
    end)
    
    HoverTrigger.MouseEnter:Connect(function()
        if self.TooltipRef then
            self.TooltipRef.Text = " UUID: " .. uuid .. " "
            self.TooltipRef.Visible = true
            if UUIDDisplay:FindFirstChild("UIStroke") then
                UUIDDisplay.UIStroke.Color = THEME.AccentPurple
            end
        end
    end)
    
    HoverTrigger.MouseLeave:Connect(function()
        if self.TooltipRef then
            self.TooltipRef.Visible = false
            if UUIDDisplay:FindFirstChild("UIStroke") then
                UUIDDisplay.UIStroke.Color = THEME.GlassStroke
            end
        end
    end)
end

-- ============================
-- PET ACTION HANDLERS
-- ============================
function DupeTab:OnDeletePets()
    local THEME = self.Config.THEME
    
    if self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("🔒 Close Trade first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    local count = 0
    for _ in pairs(self.StateManager.selectedPets) do count = count + 1 end
    if count == 0 then return end
    
    self:ShowConfirm("Delete " .. count .. " Pets?", function()
        self.TradeManager.DeleteSelectedPets(self.StatusLabel, function()
            task.wait(0.5)
            self.StateManager.selectedPets = {}
            self:RefreshInventory()
        end, self.StateManager, self.Utils)
    end)
end

function DupeTab:OnEvolvePets()
    if self.BtnEvoPet:GetAttribute("IsValid") then
        self.TradeManager.ExecuteEvolution(self.StatusLabel, function()
            task.wait(0.6)
            self:RefreshInventory()
            self:UpdateEvoButtonState()
        end, self.StateManager)
    end
end

function DupeTab:OnDupePets()
    self.TradeManager.ExecutePetDupe(self.StatusLabel, self.StateManager, self.Utils)
end

function DupeTab:UpdateEvoButtonState()
    if not self.BtnEvoPet then return end
    
    local THEME = self.Config.THEME
    local replica = ReplicaListener:GetReplica()
    local myPets = replica and replica.Data.PetsService and replica.Data.PetsService.Pets or {}
    
    local selectedPetsData = {}
    local count = 0
    
    for uuid, _ in pairs(self.StateManager.selectedPets) do
        if myPets[uuid] then
            table.insert(selectedPetsData, myPets[uuid])
            count = count + 1
        end
    end
    
    local btnText = "EVOLVE (0/3)"
    local isValid = false
    
    if count ~= 3 then
        btnText = "SELECT 3 (" .. count .. "/3)"
    else
        local firstPet = selectedPetsData[1]
        local allSameName = true
        local allSameEvo = true
        local notMaxLevel = true
        
        for i = 2, #selectedPetsData do
            if selectedPetsData[i].Name ~= firstPet.Name then
                allSameName = false
            end
            if (selectedPetsData[i].Evolution or 0) ~= (firstPet.Evolution or 0) then
                allSameEvo = false
            end
        end
        
        if (firstPet.Evolution or 0) >= 2 then
            notMaxLevel = false
        end
        
        if not allSameName then
            btnText = "MISMATCH NAME"
        elseif not allSameEvo then
            btnText = "MISMATCH EVO"
        elseif not notMaxLevel then
            btnText = "MAX LEVEL"
        else
            btnText = "🧬 EVOLVE NOW"
            isValid = true
        end
    end
    
    self.BtnEvoPet.Text = btnText
    
    if isValid then
        self.BtnEvoPet.BackgroundColor3 = THEME.AccentPurple
        self.BtnEvoPet.AutoButtonColor = true
        self.BtnEvoPet.TextTransparency = 0
    else
        self.BtnEvoPet.BackgroundColor3 = THEME.BtnDisabled
        self.BtnEvoPet.AutoButtonColor = false
        self.BtnEvoPet.TextTransparency = 0.5
    end
    
    self.BtnEvoPet:SetAttribute("IsValid", isValid)
end

-- ============================
-- POPUPS
-- ============================
function DupeTab:ShowQuantityPopup(itemData, onConfirm)
    -- Implementation same as original
    local THEME = self.Config.THEME
    
    local PopupFrame = Instance.new("Frame", self.ScreenGui)
    PopupFrame.Size = UDim2.new(1, 0, 1, 0)
    PopupFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    PopupFrame.BackgroundTransparency = 0.3
    PopupFrame.ZIndex = 3000
    PopupFrame.BorderSizePixel = 0
    
    local popupBox = Instance.new("Frame", PopupFrame)
    popupBox.Size = UDim2.new(0, 240, 0, 150)
    popupBox.Position = UDim2.new(0.5, -120, 0.5, -75)
    popupBox.BackgroundColor3 = THEME.GlassBg
    popupBox.ZIndex = 3001
    popupBox.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(popupBox, 10)
    self.UIFactory.AddStroke(popupBox, THEME.AccentPurple, 2, 0)
    
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = popupBox,
        Text = "ENTER AMOUNT",
        Size = UDim2.new(1, 0, 0, 38),
        TextColor = THEME.TextWhite,
        Font = Enum.Font.GothamBold,
        TextSize = 13
    })
    titleLabel.ZIndex = 3002
    
    local input = Instance.new("TextBox", popupBox)
    input.Size = UDim2.new(0.85, 0, 0, 34)
    input.Position = UDim2.new(0.075, 0, 0.35, 0)
    input.Text = tostring(itemData.Default or 1)
    input.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    input.TextColor3 = THEME.TextWhite
    input.Font = Enum.Font.Code
    input.TextSize = 15
    input.ClearTextOnFocus = false
    input.ZIndex = 3002
    input.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(input, 6)
    self.UIFactory.AddStroke(input, THEME.GlassStroke, 1, 0.5)
    
    local maxValue = itemData.Max or 999999
    local inputConn = self.Utils.SanitizeNumberInput(input, maxValue)
    
    local confirmBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0.85, 0, 0, 34),
        Position = UDim2.new(0.075, 0, 0.7, 0),
        Text = "CONFIRM",
        BgColor = THEME.AccentPurple,
        CornerRadius = 6,
        Parent = popupBox
    })
    confirmBtn.ZIndex = 3002
    
    local closeBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -30, 0, 4),
        Text = "✕",
        BgColor = THEME.Fail,
        CornerRadius = 6,
        Parent = popupBox
    })
    closeBtn.ZIndex = 3002
    
    closeBtn.MouseButton1Click:Connect(function()
        if inputConn then inputConn:Disconnect() end
        PopupFrame:Destroy()
    end)
    
    confirmBtn.MouseButton1Click:Connect(function()
        local quantity = tonumber(input.Text)
        if quantity and quantity > 0 and quantity <= maxValue then
            onConfirm(quantity)
            if inputConn then inputConn:Disconnect() end
            PopupFrame:Destroy()
        end
    end)
end

function DupeTab:ShowConfirm(text, onYes)
    local THEME = self.Config.THEME
    
    local ConfirmOverlay = Instance.new("Frame", self.ScreenGui)
    ConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
    ConfirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    ConfirmOverlay.BackgroundTransparency = 0.15
    ConfirmOverlay.ZIndex = 2000
    ConfirmOverlay.BorderSizePixel = 0
    
    local box = Instance.new("Frame", ConfirmOverlay)
    box.Size = UDim2.new(0, 310, 0, 155)
    box.Position = UDim2.new(0.5, -155, 0.5, -77.5)
    box.BackgroundColor3 = THEME.GlassBg
    box.ZIndex = 2001
    box.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(box, 10)
    self.UIFactory.AddStroke(box, THEME.Fail, 2, 0)
    
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = box,
        Text = text,
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.new(0, 0, 0, 8),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor = THEME.Fail
    })
    titleLabel.ZIndex = 2002
    
    local subLabel = self.UIFactory.CreateLabel({
        Parent = box,
        Text = "Are you sure? This cannot be undone!",
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 0, 50),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor = THEME.TextGray
    })
    subLabel.ZIndex = 2002
    subLabel.TextWrapped = true
    
    local btnContainer = Instance.new("Frame", box)
    btnContainer.Size = UDim2.new(1, 0, 0, 42)
    btnContainer.Position = UDim2.new(0, 0, 1, -50)
    btnContainer.BackgroundTransparency = 1
    btnContainer.ZIndex = 2002
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    
    local cancelBtn = self.UIFactory.CreateButton({
        Text = "CANCEL",
        Size = UDim2.new(0, 100, 0, 34),
        BgColor = THEME.BtnDefault,
        Parent = btnContainer,
        OnClick = function()
            ConfirmOverlay:Destroy()
        end
    })
    cancelBtn.ZIndex = 2003
    
    local yesBtn = self.UIFactory.CreateButton({
        Text = "YES, DELETE",
        Size = UDim2.new(0, 120, 0, 34),
        BgColor = THEME.Fail,
        Parent = btnContainer,
        OnClick = function()
            ConfirmOverlay:Destroy()
            onYes()
        end
    })
    yesBtn.ZIndex = 2003
end

return DupeTab
