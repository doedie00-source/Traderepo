-- config.lua
-- Configuration & Constants (Modern Theme)

local CONFIG = {
    VERSION = "7.2 (Modular)",
    GUI_NAME = "ModernTradeGUI",
    
    -- Window Settings
    MAIN_WINDOW_SIZE = UDim2.new(0, 750, 0, 480),
    SIDEBAR_WIDTH = 110,
    MINI_ICON_SIZE = UDim2.new(0, 50, 0, 50),
    
    -- Timing
    STATUS_RESET_DELAY = 4,
    BUTTON_CHECK_INTERVAL = 0.5,
    TRADE_RESET_THRESHOLD = 3,
    
    -- UI Spacing
    CORNER_RADIUS = 10,
    LIST_PADDING = 4,
    BUTTON_PADDING = 5,
    CARD_PADDING = 6,
    
    -- Keybind
    TOGGLE_KEY = Enum.KeyCode.T,
}

-- 🎨 Modern Theme (Glassmorphism + Vibrant)
local THEME = {
    -- Base Colors
    MainBg = Color3.fromRGB(15, 15, 20),
    MainTransparency = 0.05,
    PanelBg = Color3.fromRGB(25, 25, 32),
    PanelTransparency = 0.3,
    
    -- Glass Effect
    GlassBg = Color3.fromRGB(30, 30, 38),
    GlassTransparency = 0.15,
    GlassStroke = Color3.fromRGB(70, 70, 85),
    
    -- Text
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(170, 170, 180),
    TextDim = Color3.fromRGB(120, 120, 130),
    
    -- Buttons
    BtnDefault = Color3.fromRGB(45, 45, 55),
    BtnHover = Color3.fromRGB(55, 55, 65),
    BtnSelected = Color3.fromRGB(88, 101, 242), -- Discord Purple
    BtnMainTab = Color3.fromRGB(35, 35, 42),
    BtnMainTabSelected = Color3.fromRGB(88, 101, 242),
    BtnDupe = Color3.fromRGB(114, 137, 218), -- Light Blue
    BtnDisabled = Color3.fromRGB(35, 35, 40),  -- เข้มกว่าเดิม
    TextDisabled = Color3.fromRGB(90, 90, 95),
    
    -- Status Colors
    Success = Color3.fromRGB(67, 181, 129), -- Green
    Fail = Color3.fromRGB(240, 71, 71), -- Red
    Warning = Color3.fromRGB(250, 166, 26), -- Yellow
    Info = Color3.fromRGB(88, 101, 242), -- Purple
    
    -- Special
    ItemInv = Color3.fromRGB(67, 181, 129),
    ItemEquip = Color3.fromRGB(240, 71, 71),
    PlayerBtn = Color3.fromRGB(250, 166, 26),
    DupeReady = Color3.fromRGB(35, 209, 96),
    
    -- Cards
    CardBg = Color3.fromRGB(32, 34, 42),
    CardStrokeSelected = Color3.fromRGB(88, 101, 242),
    CardStrokeLocked = Color3.fromRGB(240, 71, 71),
    CrateSelected = Color3.fromRGB(67, 181, 129),
    
    -- Accent
    StarColor = Color3.fromRGB(255, 215, 0),
    AccentPurple = Color3.fromRGB(88, 101, 242),
    AccentBlue = Color3.fromRGB(114, 137, 218),
    AccentGreen = Color3.fromRGB(67, 181, 129),
}

local DUPE_RECIPES = {
    Items = {
        -- [SCROLLS]
        {Name = "Dark Scroll", Tier = 5, RequiredTiers = {3, 4, 6}, Service = "Scrolls", Image = "83561916475671"},
        
        -- [TICKETS]
        {Name = "Void Ticket", Tier = 3, RequiredTiers = {4, 5, 6}, Service = "Tickets", Image = "85868652778541"},
        {Name = "Summer Ticket", Tier = 4, RequiredTiers = {3, 5, 6}, Service = "Tickets", Image = "104675798190180"},
        {Name = "Eternal Ticket", Tier = 5, RequiredTiers = {3, 4, 6}, Service = "Tickets", Image = "130196431947308"},
        {Name = "Arcade Ticket", Tier = 6, RequiredTiers = {3, 4, 5}, Service = "Tickets", Image = "104884644514614"},
        
        -- [POTIONS]
        {Name = "White Strawberry", Tier = 1, RequiredTiers = {2}, Service = "Strawberry", Image = "79066822879876"},
        {Name = "Mega Luck Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Luck Potion", Image = "131175270021637"},
        {Name = "Mega Wins Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Wins Potion", Image = "77652691143188"},
        {Name = "Mega Exp Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Exp Potion", Image = "72861583354784"},
    },
    Crates = {},
    Pets = {}
}

return {
    CONFIG = CONFIG,
    THEME = THEME,
    DUPE_RECIPES = DUPE_RECIPES
}
