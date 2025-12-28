-- tab_players.lua
-- โมดูลจัดการหน้า Players (รายชื่อผู้เล่นและการส่งคำขอเทรด)
-- Version: Full Logic

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TabPlayers = {}
TabPlayers.__index = TabPlayers

function TabPlayers.new(deps)
    local self = setmetatable({}, TabPlayers)
    -- รับ Dependencies ที่จำเป็น
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    
    self.Parent = nil 
    self.Buttons = {} -- เก็บรายการปุ่มเพื่อใช้อัปเดตสถานะ
    return self
end

function TabPlayers:Init(parentFrame)
    self.Parent = parentFrame
    local THEME = self.Config.THEME
    
    -- สร้าง Container หลัก
    local container = Instance.new("ScrollingFrame", parentFrame)
    container.Name = "PlayersContainer"
    container.Size = UDim2.new(1, -10, 1, -10)
    container.Position = UDim2.new(0, 5, 0, 5)
    container.BackgroundTransparency = 1
    container.ScrollBarThickness = 4
    container.ScrollBarImageColor3 = THEME.BtnSelected
    self.Container = container

    -- จัด Layout แบบ Grid (ตาราง)
    local layout = Instance.new("UIGridLayout", container)
    layout.CellSize = UDim2.new(0, 190, 0, 55) -- ขนาดปุ่มผู้เล่น
    layout.CellPadding = UDim2.new(0, 8, 0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- เรียกแสดงรายชื่อครั้งแรก
    self:RefreshList()
end

function TabPlayers:RefreshList()
    if not self.Container then return end
    
    -- ล้างปุ่มเก่าทิ้ง
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    self.Buttons = {}

    local THEME = self.Config.THEME
    local CONFIG = self.Config.CONFIG

    local sortedPlayers = Players:GetPlayers()
    table.sort(sortedPlayers, function(a, b) return a.Name < b.Name end)

    for _, player in ipairs(sortedPlayers) do
        if player ~= LocalPlayer then
            -- สร้างปุ่มผู้เล่น
            local btn = self.UIFactory.CreateButton({
                Parent = self.Container,
                Text = "", -- เราจะใส่ Custom Label ข้างในแทน
                Size = UDim2.new(0, 190, 0, 55),
                BgColor = THEME.BtnDefault,
                CornerRadius = CONFIG.CORNER_RADIUS,
                OnClick = function()
                    -- ส่งคำสั่งเทรดเมื่อกด
                    print("🔄 Requesting trade with: " .. player.Name)
                    self.TradeManager.ForceTradeWith(player, nil, self.StateManager, self.Utils) 
                end
            })

            -- ตกแต่งภายในปุ่ม (รูป + ชื่อ)
            -- 1. รูปหน้าตัวละคร
            local avatar = Instance.new("ImageLabel", btn)
            avatar.Size = UDim2.new(0, 40, 0, 40)
            avatar.Position = UDim2.new(0, 8, 0.5, -20)
            avatar.BackgroundTransparency = 1
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
            
            local corner = Instance.new("UICorner", avatar)
            corner.CornerRadius = UDim.new(1, 0)

            -- 2. ชื่อผู้เล่น
            local nameLabel = self.UIFactory.CreateLabel({
                Parent = btn,
                Text = player.DisplayName,
                Position = UDim2.new(0, 55, 0, 5),
                Size = UDim2.new(1, -60, 0, 20),
                TextXAlign = Enum.TextXAlignment.Left,
                TextColor = THEME.TextWhite,
                Font = Enum.Font.GothamBold,
                TextSize = 13
            })

            -- 3. ชื่อจริง (@username)
            local userLabel = self.UIFactory.CreateLabel({
                Parent = btn,
                Text = "@" .. player.Name,
                Position = UDim2.new(0, 55, 0, 25),
                Size = UDim2.new(1, -60, 0, 15),
                TextXAlign = Enum.TextXAlignment.Left,
                TextColor = THEME.TextGray,
                TextSize = 11
            })

            -- เก็บข้อมูลปุ่มไว้สำหรับ Update Loop
            btn:SetAttribute("OriginalColor", THEME.BtnDefault)
            btn:SetAttribute("PlayerName", player.Name)
            table.insert(self.Buttons, btn)
        end
    end
    
    -- ปรับขนาด ScrollingFrame ตามจำนวนของ
    local layout = self.Container:FindFirstChild("UIGridLayout")
    if layout then
        self.Container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end
end

function TabPlayers:UpdateButtonStates()
    -- ฟังก์ชันนี้จะถูกเรียกโดย Loop ใน GUI หลัก เพื่อเช็คสถานะ
    local THEME = self.Config.THEME
    
    for _, btn in ipairs(self.Buttons) do
        local pName = btn:GetAttribute("PlayerName")
        local player = Players:FindFirstChild(pName)
        
        if player then
            -- ตัวอย่าง Logic: เช็คว่าเขาว่างไหม (ในอนาคตอาจเช็ค Attribute ในเกม)
            -- ตอนนี้ใช้สีพื้นฐานไปก่อน
            local isBusy = false 
            
            if isBusy then
                btn.BackgroundColor3 = THEME.CardStrokeLocked
            else
                btn.BackgroundColor3 = btn:GetAttribute("OriginalColor")
            end
        else
            -- ถ้าผู้เล่นออกเกมไปแล้ว ให้ปุ่มเป็นสีเทาเข้ม
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        end
    end
end

return TabPlayers
