-- tab_dupe.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tab = {}
Tab.__index = Tab

function Tab.new(deps)
    local self = setmetatable({}, Tab)
    self.Config = deps.Config
    self.UIFactory = deps.UIFactory
    self.TradeManager = deps.TradeManager
    self.InventoryManager = deps.InventoryManager
    self.StateManager = deps.StateManager
    self.Utils = deps.Utils
    
    self.CurrentSubTab = "Items"
    return self
end

function Tab:Render(parentFrame, statusLabel)
    self.ParentFrame = parentFrame
    self.StatusLabel = statusLabel
    local THEME = self.Config.THEME
    
    -- 1. Sub-Tabs Bar
    local topBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, -20, 0, 35),
        Position = UDim2.new(0, 10, 0, 5),
        BgTransparency = 1,
        Parent = parentFrame
    })
    
    local list = Instance.new("UIListLayout", topBar)
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 5)
    
    local subTabs = {"Items", "Crates", "Pets"}
    for _, name in ipairs(subTabs) do
        local isSelected = (self.CurrentSubTab == name)
        self.UIFactory.CreateButton({
            Text = name,
            Size = UDim2.new(0, 80, 1, 0),
            BgColor = isSelected and THEME.BtnSelected or THEME.BtnDefault,
            TextColor = isSelected and Color3.new(1,1,1) or THEME.TextGray,
            Parent = topBar,
            OnClick = function()
                self.CurrentSubTab = name
                self.StateManager.currentDupeTab = name -- Sync state
                self:Render(parentFrame, statusLabel) -- Re-render
            end
        })
    end
    
    -- 2. Inventory Grid Container
    self.InvContainer = self.UIFactory.CreateScrollingFrame({
        Size = UDim2.new(1, -20, 1, -95), -- Space for Topbar & BottomBar
        Position = UDim2.new(0, 10, 0, 50),
        Parent = parentFrame
    })
    
    local grid = Instance.new("UIGridLayout", self.InvContainer)
    grid.CellSize = UDim2.new(0, 100, 0, 130)
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    
    -- 3. Action Bar (Bottom)
    self:RenderActionBar(parentFrame)
    
    -- 4. Load Content
    self:Refresh()
end

function Tab:RenderActionBar(parentFrame)
    local THEME = self.Config.THEME
    
    -- ล้าง Action Bar เก่าถ้ามี (ป้องกันการซ้อนทับ)
    if self.ActionBar and self.ActionBar.Parent then self.ActionBar:Destroy() end

    self.ActionBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 10, 1, -40),
        BgTransparency = 1,
        Parent = parentFrame,
        ZIndex = 5
    })
    
    local list = Instance.new("UIListLayout", self.ActionBar)
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 5)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    
    -- Logic ปุ่มตาม SubTab
    if self.CurrentSubTab == "Pets" then
        self.UIFactory.CreateButton({
            Text = "DELETE SELECTED",
            Size = UDim2.new(0, 130, 0, 30),
            BgColor = THEME.Fail,
            Parent = self.ActionBar,
            OnClick = function()
                self.TradeManager.DeleteSelectedPets(self.StatusLabel, function() self:Refresh() end, self.StateManager, self.Utils)
            end
        })
        
        self.UIFactory.CreateButton({
            Text = "EVOLVE SELECTED",
            Size = UDim2.new(0, 130, 0, 30),
            BgColor = Color3.fromRGB(170, 0, 255),
            Parent = self.ActionBar,
            OnClick = function()
                self.TradeManager.ExecuteEvolution(self.StatusLabel, function() self:Refresh() end, self.StateManager)
            end
        })
    elseif self.CurrentSubTab == "Crates" then
        self.UIFactory.CreateButton({
            Text = "ADD 1K ALL",
            Size = UDim2.new(0, 100, 0, 30),
            BgColor = Color3.fromRGB(0, 140, 255),
            Parent = self.ActionBar,
            OnClick = function()
               -- Add 1k logic placeholder
               self.StateManager:SetStatus("Added 1k to all crates!", nil, self.StatusLabel)
            end
        })
    end
end

function Tab:Refresh()
    if not self.InvContainer or not self.InvContainer.Parent then return end
    
    self.InvContainer:ClearAllChildren()
    local grid = Instance.new("UIGridLayout", self.InvContainer)
    grid.CellSize = UDim2.new(0, 110, 0, 140)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    
    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then return end
    
    local THEME = self.Config.THEME
    local RECIPES = self.Config.DUPE_RECIPES
    
    -- === LOGIC ITEMS ===
    if self.CurrentSubTab == "Items" then
        for _, item in ipairs(RECIPES.Items) do
            local hasItem = self.InventoryManager.HasItem(item.Service, item.Tier, playerData)
            self:CreateCard({
                Name = item.Name,
                Image = "rbxassetid://" .. item.Image,
                Locked = not hasItem,
                OnClick = function()
                    local tradeItem = {
                        Name = item.Name, Guid = item.Tier,
                        Service = item.Service, Amount = 1,
                        Category = "Items", Type = "Item"
                    }
                    self.StateManager:AddToTrade(item.Name, tradeItem)
                    self.TradeManager.ProcessTradeQueue(self.StatusLabel, self.StateManager, self.Utils)
                end
            })
        end

    -- === LOGIC CRATES ===
    elseif self.CurrentSubTab == "Crates" then
        local CratesInfo = self.TradeManager.CratesInfo -- ดึงจาก TradeManager
        
        -- Loop Crates (Sort หรือ Loop ตามลำดับถ้ามี table)
        for _, crateName in pairs(playerData.CratesService.Inventory or {}) do
             -- เนื่องจากผมไม่เห็นโครงสร้าง CratesInfo แบบเต็ม 
             -- ผมจะสมมติ loop เบื้องต้น ถ้า key คือชื่อ
             -- (ในโค้ดจริงคุณอาจจะต้อง loop CratesInfo แล้วเช็คจำนวนเอา)
        end
        
        -- ใช้ Mock logic เพื่อแสดงผล (คุณเอา loop เดิมมาใส่ตรงนี้ได้เลย)
        if CratesInfo then
            for name, info in pairs(CratesInfo) do
                local amt = 0
                if playerData.CratesService.Inventory[name] then
                    amt = playerData.CratesService.Inventory[name]
                end
                
                self:CreateCard({
                    Name = name,
                    SubText = "x" .. Utils.FormatNumber(amt),
                    Image = "rbxassetid://" .. (info.Image or ""),
                    OnClick = function()
                         -- Logic Add Crate
                         if self.StateManager:ToggleCrateSelection(name, amt) then
                             -- Update UI border (ต้องเขียนเพิ่ม)
                         end
                    end
                })
            end
        end

    -- === LOGIC PETS ===
    elseif self.CurrentSubTab == "Pets" then
        local collection = playerData.PetsService.Collection or {}
        for uuid, petData in pairs(collection) do
            if not petData.Locked then -- ไม่โชว์ตัวล็อค
                local details = self.Utils.GetItemDetails(petData, "Pets")
                
                -- Check selection logic
                local isSelected = self.StateManager.selectedPets[uuid] ~= nil
                local strokeColor = isSelected and THEME.BtnSelected or THEME.CardStrokeLocked
                
                self:CreateCard({
                    Name = petData.Name,
                    SubText = details,
                    Image = "rbxassetid://" .. (self.TradeManager.PetsInfo[petData.Name] and self.TradeManager.PetsInfo[petData.Name].Image or ""),
                    StrokeColor = strokeColor,
                    OnClick = function()
                        self.StateManager:TogglePetSelection(uuid)
                        self:Refresh() -- Refresh เพื่ออัพเดทสีขอบ
                    end
                })
            end
        end
    end
end

function Tab:CreateCard(props)
    local THEME = self.Config.THEME
    local card = self.UIFactory.CreateFrame({
        Parent = self.InvContainer,
        BgColor = THEME.PanelBg,
        CornerRadius = 6,
        Stroke = true
    })
    
    if props.StrokeColor then
        card.UIStroke.Color = props.StrokeColor
    elseif props.Locked then
        card.UIStroke.Color = THEME.CardStrokeLocked
        card.BackgroundTransparency = 0.7
    end
    
    -- Image
    self.UIFactory.CreateImage({
        Size = UDim2.new(0, 70, 0, 70),
        Position = UDim2.new(0.5, -35, 0, 10),
        Image = props.Image or "",
        Parent = card
    })
    
    -- Name
    self.UIFactory.CreateLabel({
        Text = props.Name,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 85),
        TextWrapped = true,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = card
    })
    
    -- Subtext
    if props.SubText then
        self.UIFactory.CreateLabel({
            Text = props.SubText,
            Size = UDim2.new(1, -10, 0, 15),
            Position = UDim2.new(0, 5, 0, 105),
            TextColor = THEME.TextGray,
            TextSize = 10,
            Parent = card
        })
    end
    
    -- Click overlay
    self.UIFactory.CreateButton({
        Size = UDim2.new(1, 0, 1, 0),
        BgTransparency = 1,
        Text = "",
        Parent = card,
        OnClick = props.OnClick
    })
end

return Tab
