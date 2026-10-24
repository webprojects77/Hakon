--[[
    UNIVERSAL BATTLEGROUNDS HUB v5.0 - MOBILE & DESKTOP
    Interface adaptativa com suporte completo para mobile
    Compatível com: Battlegrounds, Fighting Games, Arena Games
    Executor: Universal (Synapse, KRNL, Fluxus, etc.)
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

-- Detectar dispositivo
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local isConsole = UserInputService.GamepadEnabled

--[[ CONFIGURAÇÕES PRINCIPAIS ]]
local Config = {
    -- Combat
    AimAssist = false,
    AimSensitivity = 0.5,
    CameraLock = false,
    TargetPart = "Head",
    TargetPriority = "Distance",
    FOVCircle = false,
    FOVSize = 150,
    FOVColor = Color3.fromRGB(255, 255, 255),
    Whitelist = {},
    Blacklist = {},
    TargetSwitching = false,
    
    -- ESP
    ESPEnabled = true,
    NameESP = true,
    DistanceESP = true,
    HealthESP = true,
    HealthBar = true,
    SkeletonESP = true,
    BoxESP = true,
    GlowESP = true,
    Tracers = true,
    OffScreenIndicators = true,
    TeamColors = true,
    VisibilityCheck = true,
    RenderDistance = 500,
    HitboxVisualization = false,
    
    -- Colors
    ESPColor = Color3.fromRGB(255, 255, 255),
    TeamColor = Color3.fromRGB(0, 255, 0),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    RGBMode = false,
    RainbowMode = false,
    MultiColor = false,
    ColorPalette = {Color3.fromRGB(255,0,0), Color3.fromRGB(0,255,0), Color3.fromRGB(0,0,255)},
    AnimationSpeed = 1,
    GlowIntensity = 1,
    Transparency = 0,
    OutlineThickness = 1,
    GradientEffects = false,
    
    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    GravityModifier = 1,
    FlightMode = false,
    FlightSpeed = 50,
    KnockbackEnabled = false,
    KnockbackPower = 100,
    
    -- UI
    UIScale = 1,
    CompactMode = false,
    ThemeColor = Color3.fromRGB(30, 30, 30),
    AccentColor = Color3.fromRGB(255, 100, 0),
    ReducedMotion = false,
    Minimized = false,
    WindowSize = Vector2.new(400, 500),
    
    -- Keybinds
    ToggleKey = Enum.KeyCode.RightShift,
    ESPKey = Enum.KeyCode.E,
    LockKey = Enum.KeyCode.L,
    FlightKey = Enum.KeyCode.F,
    TargetSwitchKey = Enum.KeyCode.Tab,
    
    -- Diagnostics
    FPSMonitor = false,
    DebugOverlay = false,
    
    -- Config Management
    ConfigPresets = {},
    CurrentConfig = "Default",
}

--[[ VARIÁVEIS GLOBAIS ]]
local target = nil
local targetIndex = 1
local flightConnection = nil
local espConnections = {}
local uiElements = {}
local isOpen = true
local fpsFrames = 0
local fpsTime = 0
local fpsValue = 0
local selectedColorIndex = 1
local colorSequence = {}

--[[ FUNÇÕES DE UTILIDADE ]]
function GetCharacter(plr)
    return plr.Character or plr.CharacterAdded:Wait()
end

function GetRootPart(plr)
    local char = GetCharacter(plr)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

function GetHumanoid(plr)
    local char = GetCharacter(plr)
    return char:FindFirstChildOfClass("Humanoid")
end

function IsAlive(plr)
    local hum = GetHumanoid(plr)
    return hum and hum.Health > 0 and hum.Health <= hum.MaxHealth
end

function IsWhitelisted(plr)
    if #Config.Whitelist > 0 then
        for _, name in ipairs(Config.Whitelist) do
            if plr.Name == name then
                return true
            end
        end
        return false
    end
    return true
end

function IsBlacklisted(plr)
    for _, name in ipairs(Config.Blacklist) do
        if plr.Name == name then
            return true
        end
    end
    return false
end

function CanTarget(plr)
    return plr ~= player and IsAlive(plr) and IsWhitelisted(plr) and not IsBlacklisted(plr)
end

function GetClosestPlayer()
    local closest = nil
    local shortestDistance = math.huge
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if CanTarget(plr) then
            local root = GetRootPart(plr)
            if root then
                local distance = (root.Position - camera.CFrame.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closest = plr
                end
            end
        end
    end
    
    return closest
end

function GetPlayersByPriority()
    local players = {}
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if CanTarget(plr) then
            table.insert(players, plr)
        end
    end
    
    if Config.TargetPriority == "Distance" then
        table.sort(players, function(a, b)
            local rootA = GetRootPart(a)
            local rootB = GetRootPart(b)
            if rootA and rootB then
                return (rootA.Position - camera.CFrame.Position).Magnitude < 
                       (rootB.Position - camera.CFrame.Position).Magnitude
            end
            return false
        end)
    elseif Config.TargetPriority == "Direction" then
        table.sort(players, function(a, b)
            local rootA = GetRootPart(a)
            local rootB = GetRootPart(b)
            if rootA and rootB then
                local dirA = (rootA.Position - camera.CFrame.Position).Unit
                local dirB = (rootB.Position - camera.CFrame.Position).Unit
                local forward = camera.CFrame.LookVector
                return dirA:Dot(forward) > dirB:Dot(forward)
            end
            return false
        end)
    end
    
    return players
end

function GetTargetPart(plr)
    local char = GetCharacter(plr)
    if Config.TargetPart == "Head" then
        return char:FindFirstChild("Head")
    elseif Config.TargetPart == "Torso" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    elseif Config.TargetPart == "Random" then
        local parts = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}
        local part = parts[math.random(1, #parts)]
        return char:FindFirstChild(part)
    end
    return char:FindFirstChild("Head")
end

function IsVisible(part)
    if not Config.VisibilityCheck then return true end
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin).Unit * 500
    local ray = Ray.new(origin, direction)
    local hit, position = workspace:FindPartOnRay(ray, player.Character, false, true)
    
    if hit then
        return hit:IsDescendantOf(part.Parent)
    end
    return true
end

function SwitchTarget()
    local players = GetPlayersByPriority()
    if #players == 0 then return end
    
    targetIndex = targetIndex + 1
    if targetIndex > #players then targetIndex = 1 end
    
    target = players[targetIndex]
    Notify("Target", "Alvo: " .. target.Name)
end

--[[ SISTEMA DE CORES ]]
function GetDynamicColor()
    if Config.RainbowMode then
        local hue = (tick() * Config.AnimationSpeed) % 1
        return Color3.fromHSV(hue, 1, 1)
    elseif Config.RGBMode then
        local hue = (tick() * 0.5 * Config.AnimationSpeed) % 1
        return Color3.fromHSV(hue, 1, 1)
    elseif Config.MultiColor then
        local index = math.floor(tick() * Config.AnimationSpeed) % #Config.ColorPalette + 1
        return Config.ColorPalette[index]
    end
    
    return Config.ESPColor
end

function GetESPColor(plr)
    if Config.TeamColors and plr.Team == player.Team then
        return Config.TeamColor
    end
    
    return GetDynamicColor()
end

--[[ SISTEMA DE ESP AVANÇADO ]]
function CreateESP(plr)
    local esp = {}
    
    -- Name ESP
    esp.NameLabel = Drawing.new("Text")
    esp.NameLabel.Size = 16
    esp.NameLabel.Center = true
    esp.NameLabel.Outline = true
    esp.NameLabel.Font = Drawing.Fonts.UI
    
    -- Distance ESP
    esp.DistanceLabel = Drawing.new("Text")
    esp.DistanceLabel.Size = 13
    esp.DistanceLabel.Center = true
    esp.DistanceLabel.Outline = true
    esp.DistanceLabel.Font = Drawing.Fonts.UI
    
    -- Health ESP
    esp.HealthLabel = Drawing.new("Text")
    esp.HealthLabel.Size = 13
    esp.HealthLabel.Center = true
    esp.HealthLabel.Outline = true
    esp.HealthLabel.Font = Drawing.Fonts.UI
    
    -- Health Bar
    esp.HealthBarBackground = Drawing.new("Square")
    esp.HealthBarBackground.Thickness = 2
    esp.HealthBarBackground.Color = Color3.fromRGB(30, 30, 30)
    
    esp.HealthBar = Drawing.new("Square")
    esp.HealthBar.Thickness = 2
    
    -- Box ESP
    esp.Box = Drawing.new("Square")
    esp.Box.Thickness = Config.OutlineThickness
    
    -- Glow ESP
    esp.Glow = Drawing.new("Square")
    esp.Glow.Thickness = Config.OutlineThickness + 4
    esp.Glow.Transparency = 0.5
    
    -- Tracers
    esp.Tracer = Drawing.new("Line")
    esp.Tracer.Thickness = 1
    
    -- Skeleton
    esp.Skeleton = {}
    for i = 1, 10 do
        esp.Skeleton[i] = Drawing.new("Line")
        esp.Skeleton[i].Thickness = 1
    end
    
    -- Off-screen indicator
    esp.Indicator = Drawing.new("Triangle")
    esp.Indicator.Thickness = 2
    
    -- Hitbox visualization
    esp.Hitbox = Drawing.new("Square")
    esp.Hitbox.Thickness = 2
    esp.Hitbox.Color = Color3.fromRGB(255, 255, 0)
    
    return esp
end

function UpdateESP(plr, esp)
    if not Config.ESPEnabled or not IsAlive(plr) then
        HideESP(esp)
        return
    end
    
    local root = GetRootPart(plr)
    local head = GetCharacter(plr):FindFirstChild("Head")
    if not root or not head then return end
    
    local screenPos, onScreen = camera:WorldToScreenPoint(root.Position)
    local headPos, headOnScreen = camera:WorldToScreenPoint(head.Position)
    
    if not onScreen then
        -- Off-screen indicator
        if Config.OffScreenIndicators then
            local direction = (root.Position - camera.CFrame.Position).Unit
            local angle = math.atan2(direction.X, -direction.Z)
            local radius = 50
            local x = camera.ViewportSize.X / 2 + math.sin(angle) * radius
            local y = camera.ViewportSize.Y / 2 - math.cos(angle) * radius
            
            esp.Indicator.Visible = true
            esp.Indicator.PointA = Vector2.new(x, y - 10)
            esp.Indicator.PointB = Vector2.new(x - 5, y + 5)
            esp.Indicator.PointC = Vector2.new(x + 5, y + 5)
            esp.Indicator.Color = GetESPColor(plr)
        end
    else
        esp.Indicator.Visible = false
    end
    
    local distance = (camera.CFrame.Position - root.Position).Magnitude
    if distance > Config.RenderDistance then
        HideESP(esp)
        return
    end
    
    local color = GetESPColor(plr)
    
    -- Name ESP
    if Config.NameESP then
        esp.NameLabel.Visible = true
        esp.NameLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 40)
        esp.NameLabel.Text = plr.Name
        esp.NameLabel.Color = color
    else
        esp.NameLabel.Visible = false
    end
    
    -- Distance ESP
    if Config.DistanceESP then
        esp.DistanceLabel.Visible = true
        esp.DistanceLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 25)
        esp.DistanceLabel.Text = string.format("%.0fm", distance)
        esp.DistanceLabel.Color = color
    else
        esp.DistanceLabel.Visible = false
    end
    
    -- Health ESP
    local hum = GetHumanoid(plr)
    if hum then
        local healthPercent = hum.Health / hum.MaxHealth
        
        -- Health text
        if Config.HealthESP then
            esp.HealthLabel.Visible = true
            esp.HealthLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 10)
            esp.HealthLabel.Text = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
            esp.HealthLabel.Color = healthPercent > 0.5 and Color3.fromRGB(0, 255, 0) or 
                                   healthPercent > 0.25 and Color3.fromRGB(255, 255, 0) or 
                                   Color3.fromRGB(255, 0, 0)
        else
            esp.HealthLabel.Visible = false
        end
        
        -- Health bar
        if Config.HealthBar then
            local barWidth = 50
            local barHeight = 4
            local barY = screenPos.Y - 5
            
            esp.HealthBarBackground.Visible = true
            esp.HealthBarBackground.Size = Vector2.new(barWidth, barHeight)
            esp.HealthBarBackground.Position = Vector2.new(screenPos.X - barWidth/2, barY)
            
            esp.HealthBar.Visible = true
            esp.HealthBar.Size = Vector2.new(barWidth * healthPercent, barHeight)
            esp.HealthBar.Position = Vector2.new(screenPos.X - barWidth/2, barY)
            esp.HealthBar.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
        else
            esp.HealthBar.Visible = false
            esp.HealthBarBackground.Visible = false
        end
    end
    
    -- Box ESP
    if Config.BoxESP then
        local size = 100 / distance * 10
        esp.Box.Visible = true
        esp.Box.Size = Vector2.new(size, size * 2)
        esp.Box.Position = Vector2.new(screenPos.X - size/2, screenPos.Y - size)
        esp.Box.Color = color
    else
        esp.Box.Visible = false
    end
    
    -- Glow ESP
    if Config.GlowESP then
        esp.Glow.Visible = true
        esp.Glow.Size = esp.Box.Size + Vector2.new(8, 8)
        esp.Glow.Position = esp.Box.Position - Vector2.new(4, 4)
        esp.Glow.Color = color
        esp.Glow.Transparency = 0.5
    else
        esp.Glow.Visible = false
    end
    
    -- Tracer
    if Config.Tracers then
        esp.Tracer.Visible = true
        esp.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
        esp.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
        esp.Tracer.Color = color
    else
        esp.Tracer.Visible = false
    end
    
    -- Skeleton
    if Config.SkeletonESP then
        local char = GetCharacter(plr)
        local skeletonParts = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
        local positions = {}
        
        for i, partName in ipairs(skeletonParts) do
            local part = char:FindFirstChild(partName)
            if part then
                local pos, vis = camera:WorldToScreenPoint(part.Position)
                positions[i] = Vector2.new(pos.X, pos.Y)
            end
        end
        
        for i = 1, 9 do
            if positions[i] and positions[i + 1] then
                esp.Skeleton[i].Visible = true
                esp.Skeleton[i].From = positions[i]
                esp.Skeleton[i].To = positions[i + 1]
                esp.Skeleton[i].Color = color
            else
                esp.Skeleton[i].Visible = false
            end
        end
    else
        for i = 1, 10 do
            esp.Skeleton[i].Visible = false
        end
    end
    
    -- Hitbox Visualization
    if Config.HitboxVisualization then
        esp.Hitbox.Visible = true
        local size = 80 / distance * 10
        esp.Hitbox.Size = Vector2.new(size, size * 2)
        esp.Hitbox.Position = Vector2.new(screenPos.X - size/2, screenPos.Y - size)
    else
        esp.Hitbox.Visible = false
    end
end

function HideESP(esp)
    esp.NameLabel.Visible = false
    esp.DistanceLabel.Visible = false
    esp.HealthLabel.Visible = false
    esp.HealthBar.Visible = false
    esp.HealthBarBackground.Visible = false
    esp.Box.Visible = false
    esp.Glow.Visible = false
    esp.Tracer.Visible = false
    esp.Indicator.Visible = false
    esp.Hitbox.Visible = false
    for i = 1, 10 do
        esp.Skeleton[i].Visible = false
    end
end

--[[ SISTEMA DE AIM ASSIST AVANÇADO ]]
function UpdateAimAssist()
    if not Config.AimAssist and not Config.CameraLock then return end
    
    local targetPlayer = target or GetClosestPlayer()
    if not targetPlayer or not CanTarget(targetPlayer) then
        target = nil
        return
    end
    
    local targetPart = GetTargetPart(targetPlayer)
    if not targetPart then return end
    
    local screenPos = camera:WorldToScreenPoint(targetPart.Position)
    
    if Config.FOVCircle then
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        
        if distance > Config.FOVSize then return end
    end
    
    if Config.CameraLock then
        local lookAt = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
        camera.CFrame = camera.CFrame:Lerp(lookAt, Config.AimSensitivity * 0.1, 0.1)
    elseif Config.AimAssist then
        -- Suave assistência de mira
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
        local delta = targetPos - mousePos
        
        if delta.Magnitude < Config.FOVSize then
            mousePos = mousePos + delta * Config.AimSensitivity * 0.01
            mouse:MoveTo(mousePos)
        end
    end
end

--[[ SISTEMA DE MOVIMENTO CORRIGIDO ]]
function UpdateMovement()
    local char = GetCharacter(player)
    local hum = GetHumanoid(player)
    local root = GetRootPart(player)
    
    if not hum or not root then return end
    
    -- WalkSpeed
    if hum.WalkSpeed ~= Config.WalkSpeed then
        hum.WalkSpeed = Config.WalkSpeed
    end
    
    -- JumpPower
    if hum.JumpPower ~= Config.JumpPower then
        hum.JumpPower = Config.JumpPower
    end
    
    -- Gravity (corrigido usando workspace.Gravity)
    local targetGravity = 196.2 * Config.GravityModifier
    if workspace.Gravity ~= targetGravity then
        workspace.Gravity = targetGravity
    end
    
    -- Flight Mode
    if Config.FlightMode then
        local velocity = Vector3.new()
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            velocity = velocity + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            velocity = velocity - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            velocity = velocity - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            velocity = velocity + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            velocity = velocity + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            velocity = velocity - Vector3.new(0, 1, 0)
        end
        
        if velocity.Magnitude > 0 then
            velocity = velocity.Unit * Config.FlightSpeed
        end
        
        root.Velocity = velocity
        hum:ChangeState(Enum.HumanoidStateType.Flying)
    elseif hum:GetState() == Enum.HumanoidStateType.Flying then
        hum:ChangeState(Enum.HumanoidStateType.Landed)
    end
end

--[[ SISTEMA DE KNOCKBACK CORRIGIDO ]]
function ApplyKnockback(plr, power)
    if not Config.KnockbackEnabled then return end
    
    local root = GetRootPart(plr)
    if root then
        local direction = (root.Position - camera.CFrame.Position).Unit
        root.Velocity = direction * power
    end
end

--[[ SISTEMA DE FOV ]]
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Radius = Config.FOVSize
fovCircle.Visible = false

function UpdateFOV()
    if Config.FOVCircle then
        fovCircle.Visible = true
        fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        fovCircle.Color = Config.FOVColor
        fovCircle.Radius = Config.FOVSize
    else
        fovCircle.Visible = false
    end
end

--[[ SISTEMA DE UI COMPLETO MOBILE/DESKTOP ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BattlegroundsHub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- CORREÇÃO 1: Usar UIScale em vez de ScreenGui.Scale
local UIScale = Instance.new("UIScale")
UIScale.Scale = Config.UIScale
UIScale.Parent = ScreenGui

-- Função para atualizar escala
function UpdateUIScale()
    UIScale.Scale = Config.UIScale
end

-- MainFrame com tamanho adaptativo
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, Config.WindowSize.X, 0, Config.WindowSize.Y)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Config.ThemeColor
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

-- Limites de tamanho
local MinSize = Instance.new("UISizeConstraint")
MinSize.MinSize = Vector2.new(300, 200)
MinSize.Parent = MainFrame

local MaxSize = Instance.new("UISizeConstraint")
MaxSize.MaxSize = Vector2.new(600, 800)
MaxSize.Parent = MainFrame

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

--[[ SISTEMA DE ARRASTAR MOBILE/DESKTOP ]]
local dragging = false
local dragStart = nil
local frameStart = nil

local function StartDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        frameStart = MainFrame.Position
    end
end

local function UpdateDrag(input)
    if dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(0, frameStart.X.Offset + delta.X, 0, frameStart.Y.Offset + delta.Y)
        
        -- Manter dentro da tela
        local maxX = camera.ViewportSize.X - MainFrame.AbsoluteSize.X
        local maxY = camera.ViewportSize.Y - MainFrame.AbsoluteSize.Y
        MainFrame.Position = UDim2.new(
            0, math.clamp(MainFrame.Position.X.Offset, 0, maxX),
            0, math.clamp(MainFrame.Position.Y.Offset, 0, maxY)
        )
    end
end

local function EndDrag()
    dragging = false
    dragStart = nil
    frameStart = nil
end

--[[ SISTEMA DE REDIMENSIONAR ]]
local resizeHandle = Instance.new("Frame")
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.BackgroundColor3 = Config.AccentColor
resizeHandle.BackgroundTransparency = 0.5
resizeHandle.Parent = MainFrame

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(1, 0)
resizeCorner.Parent = resizeHandle

local resizing = false
local resizeStart = nil
local resizeFrameSize = nil

local function StartResize(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        resizeFrameSize = MainFrame.Size
    end
end

local function UpdateResize(input)
    if resizing then
        local delta = input.Position - resizeStart
        local newSize = Vector2.new(
            math.clamp(resizeFrameSize.X.Offset + delta.X, MinSize.MinSize.X, MaxSize.MaxSize.X),
            math.clamp(resizeFrameSize.Y.Offset + delta.Y, MinSize.MinSize.Y, MaxSize.MaxSize.Y)
        )
        MainFrame.Size = UDim2.new(0, newSize.X, 0, newSize.Y)
        Config.WindowSize = newSize
    end
end

local function EndResize()
    resizing = false
    resizeStart = nil
    resizeFrameSize = nil
end

-- Conectar eventos de entrada
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- Arrastar pela barra de título
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        local absPos = MainFrame.AbsolutePosition
        local absSize = MainFrame.AbsoluteSize
        
        -- Verificar se clicou na barra de título
        if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
           pos.Y >= absPos.Y and pos.Y <= absPos.Y + 35 then
            StartDrag(input)
        end
        
        -- Verificar se clicou na alça de redimensionar
        local handlePos = resizeHandle.AbsolutePosition
        local handleSize = resizeHandle.AbsoluteSize
        if pos.X >= handlePos.X and pos.X <= handlePos.X + handleSize.X and
           pos.Y >= handlePos.Y and pos.Y <= handlePos.Y + handleSize.Y then
            StartResize(input)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input, processed)
    if processed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        UpdateDrag(input)
        UpdateResize(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        EndDrag()
        EndResize()
    end
end)

-- TitleBar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Config.AccentColor
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 8)
UICorner2.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚔️ Battlegrounds Hub v5.0"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = isMobile and 14 or 18
Title.Font = Enum.Font.GothamBold
Title.Parent = TitleBar

-- Botão Minimizar
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Position = UDim2.new(1, -35, 0, 2.5)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
MinimizeButton.BackgroundTransparency = 0.2
MinimizeButton.Text = "—"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 20
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Parent = TitleBar

local MinimizeCorner = Instance.new("UICorner")
MinimizeCorner.CornerRadius = UDim.new(0, 5)
MinimizeCorner.Parent = MinimizeButton

MinimizeButton.Activated:Connect(function()
    Config.Minimized = not Config.Minimized
    if Config.Minimized then
        MainFrame:TweenSize(UDim2.new(0, Config.WindowSize.X, 0, 35), "Out", "Quad", 0.3)
        MinimizeButton.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, Config.WindowSize.X, 0, Config.WindowSize.Y), "Out", "Quad", 0.3)
        MinimizeButton.Text = "—"
    end
end)

-- Search Bar
local SearchBar = Instance.new("TextBox")
SearchBar.Size = UDim2.new(1, -20, 0, isMobile and 35 or 25)
SearchBar.Position = UDim2.new(0, 10, 0, 40)
SearchBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SearchBar.BackgroundTransparency = 0.3
SearchBar.PlaceholderText = "🔍 Buscar configurações..."
SearchBar.Text = ""
SearchBar.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBar.TextSize = isMobile and 16 or 13
SearchBar.Font = Enum.Font.Gotham
SearchBar.Parent = MainFrame

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 5)
SearchCorner.Parent = SearchBar

-- TabContainer
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, isMobile and 50 or 40)
TabContainer.Position = UDim2.new(0, 0, 0, isMobile and 80 or 70)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

local Tabs = {"Combat", "ESP", "Movement", "Visuals", "Settings"}
local TabButtons = {}
local TabFrames = {}

for i, tabName in ipairs(Tabs) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1/#Tabs, -2, 0, isMobile and 40 or 30)
    button.Position = UDim2.new((i-1)/#Tabs, 1, 0, isMobile and 5 or 5)
    button.BackgroundColor3 = Config.ThemeColor
    button.BackgroundTransparency = 0.3
    button.Text = tabName
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = isMobile and 12 or 14
    button.Font = Enum.Font.Gotham
    button.Parent = TabContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = button
    
    TabButtons[i] = button
    
    -- Criar frame para cada tab
    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, -20, 1, -(isMobile and 130 or 120))
    frame.Position = UDim2.new(0, 10, 0, isMobile and 130 or 115)
    frame.BackgroundTransparency = 1
    frame.ScrollBarThickness = 5
    frame.Visible = (i == 1)
    frame.Parent = MainFrame
    
    TabFrames[i] = frame
    
    button.Activated:Connect(function()
        for j, frame in ipairs(TabFrames) do
            frame.Visible = (j == i)
        end
        for j, btn in ipairs(TabButtons) do
            btn.BackgroundColor3 = (j == i) and Config.AccentColor or Config.ThemeColor
        end
    end)
end

-- Função para criar toggles (com Activated para mobile)
function CreateToggle(parent, text, setting, yPos)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, isMobile and 45 or 30)
    toggle.Position = UDim2.new(0, 5, 0, yPos)
    toggle.BackgroundColor3 = Config.ThemeColor
    toggle.BackgroundTransparency = 0.3
    toggle.Text = text .. " ❌"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.TextSize = isMobile and 14 or 14
    toggle.Font = Enum.Font.Gotham
    toggle.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = toggle
    
    toggle.Activated:Connect(function()
        Config[setting] = not Config[setting]
        toggle.Text = text .. (Config[setting] and " ✅" or " ❌")
        toggle.BackgroundColor3 = Config[setting] and Config.AccentColor or Config.ThemeColor
    end)
    
    return toggle
end

-- Função para criar sliders (com Activated para mobile)
function CreateSlider(parent, text, setting, min, max, yPos)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, isMobile and 30 or 25)
    label.Position = UDim2.new(0, 5, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(Config[setting])
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = isMobile and 14 or 14
    label.Font = Enum.Font.Gotham
    label.Parent = parent
    
    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, -10, 0, isMobile and 30 or 20)
    slider.Position = UDim2.new(0, 5, 0, yPos + (isMobile and 30 or 25))
    slider.BackgroundColor3 = Config.ThemeColor
    slider.BackgroundTransparency = 0.3
    slider.Text = ""
    slider.Parent = parent
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Config.AccentColor
    fill.Parent = slider
    
    slider.Activated:Connect(function()
        local pos = mouse.X - slider.AbsolutePosition.X
        local percent = math.clamp(pos / slider.AbsoluteSize.X, 0, 1)
        Config[setting] = min + (max - min) * percent
        label.Text = text .. ": " .. string.format("%.1f", Config[setting])
        fill.Size = UDim2.new(percent, 0, 1, 0)
    end)
    
    return slider
end

-- Função para criar dropdown (com Activated para mobile)
function CreateDropdown(parent, text, options, setting, yPos)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, isMobile and 30 or 25)
    label.Position = UDim2.new(0, 5, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = isMobile and 14 or 14
    label.Font = Enum.Font.Gotham
    label.Parent = parent
    
    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(1, -10, 0, isMobile and 40 or 30)
    dropdown.Position = UDim2.new(0, 5, 0, yPos + (isMobile and 30 or 25))
    dropdown.BackgroundColor3 = Config.ThemeColor
    dropdown.BackgroundTransparency = 0.3
    dropdown.Text = tostring(Config[setting])
    dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdown.TextSize = isMobile and 14 or 14
    dropdown.Font = Enum.Font.Gotham
    dropdown.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = dropdown
    
    dropdown.Activated:Connect(function()
        local currentIndex = table.find(options, Config[setting]) or 1
        local nextIndex = currentIndex % #options + 1
        Config[setting] = options[nextIndex]
        dropdown.Text = tostring(Config[setting])
    end)
    
    return dropdown
end

-- Preencher Tabs com opções completas
-- Combat Tab
local yPos = 5
CreateToggle(TabFrames[1], "Aim Assist", "AimAssist", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[1], "Camera Lock", "CameraLock", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[1], "FOV Circle", "FOVCircle", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[1], "FOV Size", "FOVSize", 50, 300, yPos); yPos += isMobile and 70 or 55
CreateSlider(TabFrames[1], "Sensitivity", "AimSensitivity", 0.1, 1, yPos); yPos += isMobile and 70 or 55
CreateDropdown(TabFrames[1], "Target Part", {"Head", "Torso", "Random"}, "TargetPart", yPos); yPos += isMobile and 80 or 60
CreateDropdown(TabFrames[1], "Priority", {"Distance", "Direction"}, "TargetPriority", yPos); yPos += isMobile and 80 or 60
CreateToggle(TabFrames[1], "Target Switching", "TargetSwitching", yPos); yPos += isMobile and 50 or 35

-- ESP Tab
yPos = 5
CreateToggle(TabFrames[2], "ESP Enabled", "ESPEnabled", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Name ESP", "NameESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Distance ESP", "DistanceESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Health ESP", "HealthESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Health Bar", "HealthBar", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Box ESP", "BoxESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Glow ESP", "GlowESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Skeleton ESP", "SkeletonESP", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Tracers", "Tracers", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Off-screen Indicators", "OffScreenIndicators", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Team Colors", "TeamColors", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Visibility Check", "VisibilityCheck", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[2], "Hitbox Visualization", "HitboxVisualization", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[2], "Render Distance", "RenderDistance", 100, 1000, yPos); yPos += isMobile and 70 or 55

-- Movement Tab
yPos = 5
CreateSlider(TabFrames[3], "WalkSpeed", "WalkSpeed", 16, 200, yPos); yPos += isMobile and 70 or 55
CreateSlider(TabFrames[3], "JumpPower", "JumpPower", 50, 200, yPos); yPos += isMobile and 70 or 55
CreateSlider(TabFrames[3], "Gravity", "GravityModifier", 0.1, 2, yPos); yPos += isMobile and 70 or 55
CreateToggle(TabFrames[3], "Flight Mode", "FlightMode", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[3], "Flight Speed", "FlightSpeed", 10, 200, yPos); yPos += isMobile and 70 or 55
CreateToggle(TabFrames[3], "Knockback", "KnockbackEnabled", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[3], "Knockback Power", "KnockbackPower", 10, 500, yPos); yPos += isMobile and 70 or 55

-- Visuals Tab
yPos = 5
CreateToggle(TabFrames[4], "RGB Mode", "RGBMode", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[4], "Rainbow Mode", "RainbowMode", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[4], "Multi-Color", "MultiColor", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[4], "Animation Speed", "AnimationSpeed", 0.1, 5, yPos); yPos += isMobile and 70 or 55
CreateSlider(TabFrames[4], "Glow Intensity", "GlowIntensity", 0.1, 2, yPos); yPos += isMobile and 70 or 55
CreateSlider(TabFrames[4], "Outline Thickness", "OutlineThickness", 1, 5, yPos); yPos += isMobile and 70 or 55

-- Settings Tab
yPos = 5
CreateToggle(TabFrames[5], "Compact Mode", "CompactMode", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[5], "FPS Monitor", "FPSMonitor", yPos); yPos += isMobile and 50 or 35
CreateToggle(TabFrames[5], "Debug Overlay", "DebugOverlay", yPos); yPos += isMobile and 50 or 35
CreateSlider(TabFrames[5], "UI Scale", "UIScale", 0.5, 2, yPos); yPos += isMobile and 70 or 55

-- Botões Mobile para ações rápidas
if isMobile then
    -- Criar botões flutuantes para ações no mobile
    local MobileButtons = Instance.new("Frame")
    MobileButtons.Size = UDim2.new(0, 200, 0, 50)
    MobileButtons.Position = UDim2.new(0.5, -100, 1, -60)
    MobileButtons.BackgroundTransparency = 1
    MobileButtons.Parent = ScreenGui
    
    local function CreateMobileButton(text, action, xPos)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 60, 0, 45)
        button.Position = UDim2.new(0, xPos, 0, 0)
        button.BackgroundColor3 = Config.AccentColor
        button.BackgroundTransparency = 0.2
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Font = Enum.Font.GothamBold
        button.Parent = MobileButtons
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        
        button.Activated:Connect(function()
            action()
        end)
    end
    
    CreateMobileButton("ESP", function()
        Config.ESPEnabled = not Config.ESPEnabled
        Notify("ESP", Config.ESPEnabled and "Ativado" or "Desativado")
    end, 0)
    
    CreateMobileButton("Lock", function()
        if Config.CameraLock then
            Config.CameraLock = false
            target = nil
            Notify("Camera Lock", "Desativado")
        else
            target = GetClosestPlayer()
            if target then
                Config.CameraLock = true
                Notify("Camera Lock", "Alvo: " .. target.Name)
            end
        end
    end, 70)
    
    CreateMobileButton("Flight", function()
        Config.FlightMode = not Config.FlightMode
        Notify("Flight", Config.FlightMode and "Ativado" or "Desativado")
    end, 140)
end

--[[ SISTEMA DE NOTIFICAÇÕES ]]
function Notify(title, text, duration)
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, isMobile and 250 or 200, 0, isMobile and 60 or 50)
    notification.Position = UDim2.new(1, -(isMobile and 260 or 210), 0, 10)
    notification.BackgroundColor3 = Config.ThemeColor
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.4, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Config.AccentColor
    titleLabel.TextSize = isMobile and 16 or 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = notification
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0.6, 0)
    textLabel.Position = UDim2.new(0, 0, 0.4, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
     textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = isMobile and 14 or 12
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextWrapped = true
    textLabel.Parent = notification
    
    duration = duration or 3
    task.delay(duration, function()
        notification:TweenSize(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.5, true)
        task.wait(0.5)
        notification:Destroy()
    end)
end

--[[ SISTEMA DE FPS MONITOR CORRIGIDO ]]
local fpsLabel = Drawing.new("Text")
fpsLabel.Size = 16
fpsLabel.Position = Vector2.new(10, 10)
fpsLabel.Color = Color3.fromRGB(0, 255, 0)
fpsLabel.Visible = false

function UpdateFPS(deltaTime)
    fpsFrames += 1
    fpsTime += deltaTime
    
    if fpsTime >= 1 then
        fpsValue = fpsFrames
        fpsFrames = 0
        fpsTime = 0
    end
    
    if Config.FPSMonitor then
        fpsLabel.Visible = true
        fpsLabel.Text = "FPS: " .. tostring(fpsValue)
    else
        fpsLabel.Visible = false
    end
end

--[[ DEBUG OVERLAY ]]
local debugLabel = Drawing.new("Text")
debugLabel.Size = 13
debugLabel.Position = Vector2.new(10, 30)
debugLabel.Color = Color3.fromRGB(255, 255, 0)
debugLabel.Visible = false

function UpdateDebug()
    if Config.DebugOverlay then
        debugLabel.Visible = true
        local targetName = target and target.Name or "Nenhum"
        debugLabel.Text = string.format("Target: %s | FOV: %d | ESP: %s", 
            targetName, Config.FOVSize, tostring(Config.ESPEnabled))
    else
        debugLabel.Visible = false
    end
end

--[[ KEYBINDS COMPLETOS (desktop apenas) ]]
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Config.ToggleKey then
            isOpen = not isOpen
            MainFrame.Visible = isOpen
        elseif input.KeyCode == Config.ESPKey then
            Config.ESPEnabled = not Config.ESPEnabled
            Notify("ESP", Config.ESPEnabled and "Ativado" or "Desativado")
        elseif input.KeyCode == Config.LockKey then
            if Config.CameraLock then
                Config.CameraLock = false
                target = nil
                Notify("Camera Lock", "Desativado")
            else
                target = GetClosestPlayer()
                if target then
                    Config.CameraLock = true
                    Notify("Camera Lock", "Alvo: " .. target.Name)
                end
            end
        elseif input.KeyCode == Config.FlightKey then
            Config.FlightMode = not Config.FlightMode
            Notify("Flight", Config.FlightMode and "Ativado" or "Desativado")
        elseif input.KeyCode == Config.TargetSwitchKey then
            SwitchTarget()
        end
    end)
end

--[[ MAIN LOOP ]]
local espTable = {}

-- Inicializar ESP para todos os jogadores
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
        espTable[plr] = CreateESP(plr)
    end
end

Players.PlayerAdded:Connect(function(plr)
    if plr ~= player then
        espTable[plr] = CreateESP(plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if espTable[plr] then
        HideESP(espTable[plr])
        espTable[plr] = nil
    end
    
    if target == plr then
        target = nil
        Config.CameraLock = false
    end
end)

-- Loop principal CORRIGIDO
RunService.RenderStepped:Connect(function(deltaTime)
    -- Atualizar FOV
    UpdateFOV()
    
    -- Atualizar Aim Assist
    UpdateAimAssist()
    
    -- Atualizar Movimento
    UpdateMovement()
    
    -- Atualizar ESP
    for plr, esp in pairs(espTable) do
        UpdateESP(plr, esp)
    end
    
    -- FPS Monitor com deltaTime
    UpdateFPS(deltaTime)
    
    -- Atualizar Debug
    UpdateDebug()
    
    -- Verificar alvo morto
    if target and not IsAlive(target) then
        target = nil
        Config.CameraLock = false
    end
    
    -- Atualizar escala da UI
    if UIScale.Scale ~= Config.UIScale then
        UpdateUIScale()
    end
end)

--[[ INICIALIZAÇÃO ]]
Notify("Battlegrounds Hub", "v5.0 Carregado com sucesso!", 3)

-- Anti-detection com verificação de ambiente
if syn and syn.hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        
        if method == "FireServer" or method == "InvokeServer" then
            -- Bloquear certos eventos de detecção
            if self.Name == "RemoteEvent" or self.Name == "RemoteFunction" then
                -- Permitir apenas eventos essenciais
            end
        end
        
        return oldNamecall(self, ...)
    end))
end

-- Loop anti-kick com verificação de ambiente
if VirtualUser then
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end
