local JustLib = {}
JustLib.__index = JustLib

-- ====================================================================
-- 1. ГЛОБАЛЬНЫЕ НАСТРОЙКИ УВЕДОМЛЕНИЙ
-- ====================================================================
JustLib.NotificationSettings = {
    Enabled = true,
    ShowWarnings = true,
    ShowErrors = true,
    DefaultDuration = 3,
    EnableStacking = true
}

local activeNotifs = {}

-- ====================================================================
-- 2. ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: РЕКУРСИВНОЕ СОЗДАНИЕ ПАПОК
-- ====================================================================
local function ensurePathExists(path)
    if not makefolder or not isfolder then return end
    local current = ""
    for folder in string.gmatch(path, "[^/\\]+") do
        current = (current == "" and "" or current .. "/") .. folder
        if not isfolder(current) then
            pcall(makefolder, current)
        end
    end
end

-- ====================================================================
-- 3. СИСТЕМА УВЕДОМЛЕНИЙ (СТАКИНГ, ФИЛЬТРЫ, ТАЙМЕРЫ)
-- ====================================================================
function JustLib:Notify(opts)
    opts = opts or {}
    if not JustLib.NotificationSettings.Enabled then return end

    local title = opts.Title or "Уведомление"
    local text = opts.Text or ""
    local nType = opts.Type or "Info" -- "Info", "Warning", "Error"
    local duration = opts.Duration or JustLib.NotificationSettings.DefaultDuration

    -- Проверка фильтров типов
    if nType == "Warning" and not JustLib.NotificationSettings.ShowWarnings then return end
    if nType == "Error" and not JustLib.NotificationSettings.ShowErrors then return end

    -- Логика стакинга (x2, x3...)
    if JustLib.NotificationSettings.EnableStacking then
        for _, notif in ipairs(activeNotifs) do
            if notif.Title == title and notif.Text == text and notif.Frame and notif.Frame.Parent then
                notif.Count = notif.Count + 1
                notif.CountLabel.Text = "x" .. tostring(notif.Count)
                notif.CountLabel.Visible = true
                notif.ResetTimer(duration)
                return
            end
        end
    end

    -- GUI Уведомления
    local coreGui = game:GetService("CoreGui")
    local screenGui = coreGui:FindFirstChild("JustLib_Notifs")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "JustLib_Notifs"
        screenGui.Parent = coreGui
    end

    local notifFrame = Instance.new("Frame")
    notifFrame.Size = UDim2.new(0, 240, 0, 50)
    notifFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    notifFrame.BorderSizePixel = 0
    notifFrame.Parent = screenGui

    -- Индикатор типа (Акцентная полоска)
    local accentColor = Color3.fromRGB(0, 170, 255)
    if nType == "Warning" then accentColor = Color3.fromRGB(255, 170, 0) end
    if nType == "Error" then accentColor = Color3.fromRGB(255, 60, 60) end

    local sideBar = Instance.new("Frame", notifFrame)
    sideBar.Size = UDim2.new(0, 4, 1, 0)
    sideBar.BackgroundColor3 = accentColor
    sideBar.BorderSizePixel = 0

    local titleLabel = Instance.new("TextLabel", notifFrame)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Position = UDim2.new(0, 12, 0, 6)
    titleLabel.Size = UDim2.new(1, -50, 0, 16)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local textLabel = Instance.new("TextLabel", notifFrame)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.SourceSans
    textLabel.Position = UDim2.new(0, 12, 0, 24)
    textLabel.Size = UDim2.new(1, -20, 0, 20)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.RichText = true

    -- Лейбл счетчика стака (x2, x3...)
    local countLabel = Instance.new("TextLabel", notifFrame)
    countLabel.Text = "x1"
    countLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    countLabel.TextSize = 13
    countLabel.Font = Enum.Font.SourceSansBold
    countLabel.Position = UDim2.new(1, -35, 0, 6)
    countLabel.Size = UDim2.new(0, 30, 0, 16)
    countLabel.Visible = false

    local notifData = {
        Title = title,
        Text = text,
        Count = 1,
        Frame = notifFrame,
        CountLabel = countLabel
    }

    local timerThread
    notifData.ResetTimer = function(newTime)
        if timerThread then task.cancel(timerThread) end
        timerThread = task.delay(newTime, function()
            local idx = table.find(activeNotifs, notifData)
            if idx then table.remove(activeNotifs, idx) end
            notifFrame:Destroy()
        end)
    end

    table.insert(activeNotifs, notifData)
    notifData.ResetTimer(duration)
end

-- ====================================================================
-- 4. СОЗДАНИЕ ОКНА (С ПОДДЕРЖКОЙ ВЛОЖЕННЫХ ПАПОК И RICHTEXT)
-- ====================================================================
function JustLib:Window(opts)
    opts = opts or {}
    local windowTitle = opts.Title or "JustLib Hub"
    
    -- Вычисление и рекурсивное создание папки для конфигов
    local baseFolder = "JustLib_Configs"
    if opts.ConfigFolder and opts.ConfigFolder ~= "" then
        baseFolder = baseFolder .. "/" .. opts.ConfigFolder
    end
    ensurePathExists(baseFolder)

    local windowObj = {
        Folder = baseFolder,
        Tabs = {}
    }

    -- Функция добавления подсказки с поддержкой RichText
    function windowObj:AttachTooltip(guiElement, tooltipText)
        if not tooltipText or tooltipText == "" then return end
        
        guiElement.MouseEnter:Connect(function()
            -- При создании GUI подсказки:
            local ttTxt = Instance.new("TextLabel")
            ttTxt.RichText = true -- <font color="..."> работает из коробки
            ttTxt.Text = tooltipText
        end)
    end

    return windowObj
end

-- ====================================================================
-- 5. ВАШ СЕКЦИОННЫЙ БЛОК НАСТРОЕК УВЕДОМЛЕНИЙ (SETTINGS TAB)
-- ====================================================================
function JustLib:AddNotificationSettings(section)
    section:Toggle({
        Name = "Включить уведомления",
        Default = JustLib.NotificationSettings.Enabled,
        Callback = function(val)
            JustLib.NotificationSettings.Enabled = val
        end,
        Tooltip = "Позволяет полностью <font color='#FF4444'>выключить</font> всплывающие окна."
    })

    section:Toggle({
        Name = "Группировка (Стакинг x2, x3)",
        Default = JustLib.NotificationSettings.EnableStacking,
        Callback = function(val)
            JustLib.NotificationSettings.EnableStacking = val
        end,
        Tooltip = "Объединяет <font color='#FFFF00'>одинаковые</font> уведомления в одну плашку."
    })

    section:Toggle({
        Name = "Показывать предупреждения (Warnings)",
        Default = JustLib.NotificationSettings.ShowWarnings,
        Callback = function(val)
            JustLib.NotificationSettings.ShowWarnings = val
        end
    })

    section:Toggle({
        Name = "Показывать ошибки (Errors)",
        Default = JustLib.NotificationSettings.ShowErrors,
        Callback = function(val)
            JustLib.NotificationSettings.ShowErrors = val
        end
    })

    section:Slider({
        Name = "Время отображения (сек)",
        Min = 1,
        Max = 10,
        Default = JustLib.NotificationSettings.DefaultDuration,
        Callback = function(val)
            JustLib.NotificationSettings.DefaultDuration = val
        end,
        Tooltip = "Длительность показа плашки на экране."
    })
end

return JustLib
