-- config.lua
-- Configuration & Constants

local CONFIG = {
    VERSION = "7.1 (No Trade Tab)",
    GUI_NAME = "CleanTradeGUI",
    
    -- Window Settings
    MAIN_WINDOW_SIZE = UDim2.new(0, 850, 0, 550),
    SIDEBAR_WIDTH = 120,
    MINI_ICON_SIZE = UDim2.new(0, 50, 0, 50),
    
    -- Timing
    STATUS_RESET_DELAY = 4,
    BUTTON_CHECK_INTERVAL = 0.5,
    TRADE_RESET_THRESHOLD = 3,
    
    -- UI Spacing
    CORNER_RADIUS = 8,
    LIST_PADDING = 3,
    BUTTON_PADDING = 5,
    
    -- Keybind
    TOGGLE_KEY = Enum.KeyCode.T,
}

local THEME = {
    MainBg = Color3.fromRGB(20, 20, 25),
    MainTransparency = 0.1,
    PanelBg = Color3.fromRGB(10, 10, 15),
    PanelTransparency = 0.5,
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(180, 180, 180),
    BtnDefault = Color3.fromRGB(50, 50, 60),
    BtnSelected = Color3.fromRGB(0, 140, 255),
    BtnMainTab = Color3.fromRGB(40, 40, 50),
    BtnMainTabSelected = Color3.fromRGB(255, 170, 0),
    BtnDupe = Color3.fromRGB(170, 0, 255),
    BtnDisabled = Color3.fromRGB(40, 40, 40),
    TextDisabled = Color3.fromRGB(100, 100, 100),
    ItemInv = Color3.fromRGB(100, 255, 140),
    ItemEquip = Color3.fromRGB(255, 80, 80),
    PlayerBtn = Color3.fromRGB(255, 170, 0),
    Success = Color3.fromRGB(85, 255, 127),
    Fail = Color3.fromRGB(255, 85, 85),
    DupeReady = Color3.fromRGB(0, 255, 200),
    CrateSelected = Color3.fromRGB(0, 255, 100),
    CardBg = Color3.fromRGB(35, 35, 35),
    CardStrokeSelected = Color3.fromRGB(0, 255, 127),
    CardStrokeLocked = Color3.fromRGB(255, 60, 60),
    StarColor = Color3.fromRGB(255, 215, 0),
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