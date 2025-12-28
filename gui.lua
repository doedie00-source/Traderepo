--[[
    UNIVERSAL TRADER - REFACTORED (SINGLE FILE VERSION)
    Style: Sidebar + Clean Tabs
    Status: Fixed & Consolidated
]]

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- 1. CONFIG & THEME
-- ============================================================================
local CONFIG = {
    GUI_NAME = "CleanTradeGUI_V2",
    TOGGLE_KEY = Enum.KeyCode.RightControl, -- ปุ่มเปิดปิด
    SIDEBAR_WIDTH = 140,
    MAIN_SIZE = UDim2.new(0, 750, 0, 450),
}

local THEME = {
    MainBg = Color3.fromRGB(18, 18, 24),
    SidebarBg = Color3.fromRGB(25, 25, 35),
    ContentBg = Color3.fromRGB(20, 20, 28),
    TextWhite = Color3.fromRGB(240, 240, 240),
    TextGray = Color3.fromRGB(150, 150, 160),
    Accent = Color3.fromRGB(0, 120, 255),
    Success = Color3.fromRGB(50, 200, 100),
    Fail = Color3.fromRGB(255, 80, 80),
    Stroke = Color3.fromRGB(45, 45, 60),
    ItemCard = Color3.fromRGB(30, 30, 40),
}

-- ============================================================================
-- 2. UTILS & HELPERS
-- ============================================================================
local Utils = {}

function Utils.Create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        if k == "Parent" then
            inst.Parent = v
        elseif k == "Corner" then
            local corner = Instance.new("UICorner", inst)
            corner.CornerRadius = UDim.new(0, v)
        elseif k == "Stroke" then
            local stroke = Instance.new("UIStroke", inst)
            stroke.Color = v.Color or THEME.Stroke
            stroke.Thickness = v.Thickness or 1
            stroke.Transparency = v.Transparency or 0
        elseif k ~= "OnClick" and k ~= "Hover" then
            inst[k] = v
        end
    end
    
    if props.OnClick and (className == "TextButton" or className == "ImageButton") then
        inst.MouseButton1Click:Connect(props.OnClick)
    end
    return inst
end

function Utils.MakeDraggable(topBar, object)
    local dragging, dragInput, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ============================================================================
-- 3. MANAGERS (Mock Logic - เพื่อให้ UI ทำงานได้ก่อน)
-- ============================================================================
local StateManager = {
    CurrentTab = nil,
    SelectedItems = {}
}

-- ============================================================================
-- 4. TABS MODULES (แยกโซนไว้ตรงนี้)
-- ============================================================================

-- [TAB] PLAYERS
local TabPlayers = {}
function TabPlayers.Render(parent)
    -- Header
    Utils.Create("TextLabel", {
        Text = "Active Players", Font = Enum.Font.GothamBold, TextSize = 18,
        TextColor3 = THEME.TextWhite, BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 10),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent
    })

    -- Scroll List
    local scroll = Utils.Create("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -50), Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1, ScrollBarThickness = 4, Parent = parent
    })
    local listLayout = Utils.Create("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 8) })

    -- Function Refresh
    local function Refresh()
        for _, c in pairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local card = Utils.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = THEME.ItemCard,
                    Corner = 6, Parent = scroll
                })
                
                -- Avatar
                Utils.Create("ImageLabel", {
                    Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 8, 0.5, -18),
                    BackgroundColor3 = Color3.new(0,0,0), Corner = 18,
                    Image = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Placeholder
                    Parent = card
                })
                task.spawn(function()
                    local thumb = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                    card.ImageLabel.Image = thumb
                end)

                -- Name
                Utils.Create("TextLabel", {
                    Text = plr.DisplayName, Font = Enum.Font.GothamBold, TextSize = 14,
                    TextColor3 = THEME.TextWhite, BackgroundTransparency = 1,
                    Size = UDim2.new(0, 200, 0, 20), Position = UDim2.new(0, 55, 0, 5),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = card
                })
                Utils.Create("TextLabel", {
                    Text = "@" .. plr.Name, Font = Enum.Font.Gotham, TextSize = 12,
                    TextColor3 = THEME.TextGray, BackgroundTransparency = 1,
                    Size = UDim2.new(0, 200, 0, 15), Position = UDim2.new(0, 55, 0, 25),
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = card
                })

                -- Trade Button
                Utils.Create("TextButton", {
                    Text = "TRADE", Font = Enum.Font.GothamBold, TextSize = 12,
                    Size = UDim2.new(0, 80, 0, 30), Position = UDim2.new(1, -90, 0.5, -15),
                    BackgroundColor3 = THEME.Accent, TextColor3 = Color3.new(1,1,1),
                    Corner = 4, Parent = card,
                    OnClick = function()
                        print("Trade with: " .. plr.Name)
                        -- ใส่ Logic TradeManager ตรงนี้
                    end
                })
            end
        end
    end

    Players.PlayerAdded:Connect(Refresh)
    Players.PlayerRemoving:Connect(Refresh)
    Refresh()
end

-- [TAB] DUPE / INVENTORY
local TabDupe = {}
function TabDupe.Render(parent)
    local currentSubTab = "Items"
    
    -- Top Sub-Tabs
    local topBar = Utils.Create("Frame", {
        Size = UDim2.new(1, -20, 0, 35), Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1, Parent = parent
    })
    local layout = Utils.Create("UIListLayout", {
        Parent = topBar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5)
    })

    local contentArea = Utils.Create("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -50), Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1, ScrollBarThickness = 4, Parent = parent
    })
    local grid = Utils.Create("UIGridLayout", {
        Parent = contentArea, CellSize = UDim2.new(0, 100, 0, 130), CellPadding = UDim2.new(0, 8, 0, 8)
    })

    local function RenderItems()
        for _, c in pairs(contentArea:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        
        -- Mock Items Generation (ตัวอย่าง)
        local items = {}
        if currentSubTab == "Items" then
            items = { {Name="Dark Scroll"}, {Name="Void Ticket"}, {Name="Magic Orb"} }
        elseif currentSubTab == "Crates" then
            items = { {Name="Gold Crate"}, {Name="Diamond Crate"} }
        else
            items = { {Name="Dragon Pet"}, {Name="Cat Pet"} }
        end

        for _, item in ipairs(items) do
            local card = Utils.Create("Frame", {
                BackgroundColor3 = THEME.ItemCard, Corner = 6, Parent = contentArea
            })
            -- Image Placeholder
            Utils.Create("Frame", {
                Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0.5, -30, 0, 15),
                BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.5,
                Corner = 30, Parent = card
            })
            -- Name
            Utils.Create("TextLabel", {
                Text = item.Name, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 5, 0, 85),
                BackgroundTransparency = 1, TextColor3 = THEME.TextWhite, Font = Enum.Font.GothamBold,
                TextSize = 12, TextWrapped = true, Parent = card
            })
            -- Button Overlay
            Utils.Create("TextButton", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = card,
                OnClick = function()
                    print("Clicked " .. item.Name)
                end
            })
        end
    end

    -- Create SubTab Buttons
    for _, name in ipairs({"Items", "Crates", "Pets"}) do
        Utils.Create("TextButton", {
            Text = name, Size = UDim2.new(0, 80, 1, 0),
            BackgroundColor3 = (name == currentSubTab) and THEME.Accent or THEME.SidebarBg,
            TextColor3 = THEME.TextWhite, Corner = 4, Parent = topBar,
            OnClick = function(btn)
                currentSubTab = name
                RenderItems()
                -- Reset color logic here (simplified)
            end
        })
    end

    RenderItems()
end


-- ============================================================================
-- 5. MAIN GUI BUILDER
-- ============================================================================
local GUI = {}

function GUI:Init()
    -- Clean Old GUI
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end

    -- Create ScreenGui
    self.ScreenGui = Utils.Create("ScreenGui", {
        Name = CONFIG.GUI_NAME, Parent = CoreGui, 
        ZIndexBehavior = Enum.ZIndexBehavior.Global, IgnoreGuiInset = true
    })

    -- Main Window
    self.MainFrame = Utils.Create("Frame", {
        Size = CONFIG.MAIN_SIZE, Position = UDim2.new(0.5, -375, 0.5, -225),
        BackgroundColor3 = THEME.MainBg, Corner = 8, Stroke = {Color = THEME.Stroke, Thickness = 1.5},
        Parent = self.ScreenGui
    })

    -- Title Bar
    local titleBar = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.SidebarBg,
        Corner = 8, Parent = self.MainFrame
    })
    -- Fix bottom corner radius of title bar (optional visual fix)
    Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = THEME.SidebarBg, BorderSizePixel = 0, Parent = titleBar
    })
    
    Utils.Create("TextLabel", {
        Text = "  ⚡ Universal Trader Refactored", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = THEME.TextWhite, BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar
    })

    -- Close Button
    Utils.Create("TextButton", {
        Text = "×", TextSize = 20, Font = Enum.Font.Gotham,
        Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(1, -40, 0, 0),
        BackgroundTransparency = 1, TextColor3 = THEME.Fail, Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })

    Utils.MakeDraggable(titleBar, self.MainFrame)

    -- Sidebar Container
    local sidebar = Utils.Create("Frame", {
        Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -40), Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = THEME.SidebarBg, Parent = self.MainFrame
    })
    -- Sidebar Bottom Radius fix
    Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = sidebar })
    Utils.Create("Frame", { -- Hide top corners of sidebar
        Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = THEME.SidebarBg, BorderSizePixel = 0, Parent = sidebar
    })

    -- Content Container
    self.ContentFrame = Utils.Create("Frame", {
        Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH, 1, -40),
        Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 0, 40),
        BackgroundColor3 = THEME.ContentBg, Parent = self.MainFrame
    })
    Utils.Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = self.ContentFrame })
    Utils.Create("Frame", { -- Hide top/left corners
        Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0, Parent = self.ContentFrame
    })
    Utils.Create("Frame", { 
        Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0, Parent = self.ContentFrame
    })

    -- Setup Tabs
    self.Tabs = {
        {Name = "Players", Icon = "👥", Module = TabPlayers},
        {Name = "Dupe", Icon = "✨", Module = TabDupe},
    }
    
    self:RenderSidebar(sidebar)
    self:SwitchTab("Players")
end

function GUI:RenderSidebar(parent)
    local list = Utils.Create("UIListLayout", {
        Parent = parent, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    Utils.Create("UIPadding", { Parent = parent, PaddingTop = UDim.new(0, 20) })

    self.TabButtons = {}

    for _, tab in ipairs(self.Tabs) do
        local btn = Utils.Create("TextButton", {
            Text = tab.Icon .. "  " .. tab.Name,
            Size = UDim2.new(0.85, 0, 0, 40),
            BackgroundColor3 = THEME.MainBg, TextColor3 = THEME.TextGray,
            Font = Enum.Font.GothamMedium, TextSize = 14,
            Corner = 6, Parent = parent,
            OnClick = function() self:SwitchTab(tab.Name) end
        })
        self.TabButtons[tab.Name] = btn
    end
end

function GUI:SwitchTab(name)
    -- Reset Buttons
    for n, btn in pairs(self.TabButtons) do
        if n == name then
            btn.BackgroundColor3 = THEME.Accent
            btn.TextColor3 = Color3.new(1,1,1)
        else
            btn.BackgroundColor3 = THEME.MainBg
            btn.TextColor3 = THEME.TextGray
        end
    end

    -- Clear Content
    for _, c in pairs(self.ContentFrame:GetChildren()) do
        if not c:IsA("UICorner") and not c:IsA("Frame") then -- Keep styling frames
            c:Destroy()
        end
    end

    -- Render Module
    for _, tab in ipairs(self.Tabs) do
        if tab.Name == name then
            tab.Module.Render(self.ContentFrame)
            break
        end
    end
end

-- ============================================================================
-- 6. RUN
-- ============================================================================
GUI:Init()
print("✅ Fixed GUI Loaded Successfully!")
