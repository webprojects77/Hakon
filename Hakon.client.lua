local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Assets = {
	Aim = "",
	Target = "",
	Visual = "",
	Settings = "",
}

local Sounds = {
	Click = "rbxasset://sounds/button.mp3",
	On = "rbxasset://sounds/electronicpingshort.mp3",
	Off = "rbxasset://sounds/switch.mp3",
	Lock = "rbxasset://sounds/flashbulb.mp3",
}

local Config = {
	Enabled = false,
	HoldToAim = false,
	Sticky = false,
	TeamCheck = false,
	WallCheck = false,
	AliveCheck = true,
	AimPart = "Head",
	Mode = "Proximity",
	Smoothing = 0.5,
	Prediction = 0,
	FOV = 150,
	ShowFov = true,
	MaxDistance = 1000,
	TargetHud = true,
	ESP = false,
	ESPInfo = false,
	Tracers = false,
	Sounds = true,
	Volume = 0.5,
	BgOpacity = 0.6,
}

local BG_COLOR = Color3.fromRGB(12, 18, 32)
local HEADER_COLOR = Color3.fromRGB(18, 28, 48)
local OFF_COLOR = Color3.fromRGB(34, 46, 70)
local TRACK_OFF = Color3.fromRGB(60, 75, 105)
local ACCENT_COLOR = Color3.fromRGB(125, 195, 255)
local TEXT_COLOR = Color3.fromRGB(235, 245, 255)
local MUTED_COLOR = Color3.fromRGB(150, 175, 205)
local DARK_TEXT = Color3.fromRGB(10, 20, 35)

local function playSound(name)
	if not Config.Sounds then return end
	local sound = Instance.new("Sound")
	sound.SoundId = Sounds[name]
	sound.Volume = Config.Volume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function usesFov()
	return Config.Mode ~= "Proximity"
end

local function getScreenCenter()
	return camera.ViewportSize / 2
end

local function getFovCenter()
	if Config.Mode == "Mouse" then
		return UserInputService:GetMouseLocation()
	end
	return getScreenCenter()
end

local function toScreen(position)
	local pos, onScreen = camera:WorldToViewportPoint(position)
	return Vector2.new(pos.X, pos.Y), onScreen
end

local function healthColor(ratio)
	return Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(90, 230, 140), ratio)
end

local function passesTeamCheck(other)
	if not Config.TeamCheck then return true end
	if player.Team == nil or other.Team == nil then return true end
	return other.Team ~= player.Team
end

local function passesAliveCheck(humanoid)
	if not Config.AliveCheck then return true end
	return humanoid.Health > 0
end

local function passesWallCheck(character, part)
	if not Config.WallCheck then return true end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local origin = camera.CFrame.Position
	local result = workspace:Raycast(origin, part.Position - origin, params)

	if not result then return true end
	return result.Instance:IsDescendantOf(character)
end

local Scorers = {}

function Scorers.Proximity(root, _, myRoot)
	return (root.Position - myRoot.Position).Magnitude
end

function Scorers.ScreenCenter(_, screenPos)
	return (screenPos - getScreenCenter()).Magnitude
end

function Scorers.Mouse(_, screenPos)
	return (screenPos - UserInputService:GetMouseLocation()).Magnitude
end

local function evaluate(other, myRoot, fovCenter, limitByFov)
	local character = other.Character
	if other == player or not character or not passesTeamCheck(other) then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not passesAliveCheck(humanoid) then return nil end

	if (root.Position - myRoot.Position).Magnitude > Config.MaxDistance then return nil end

	local aimPart = character:FindFirstChild(Config.AimPart) or root
	local screenPos, onScreen = toScreen(aimPart.Position)

	if limitByFov and not (onScreen and (screenPos - fovCenter).Magnitude <= Config.FOV) then
		return nil
	end

	if not passesWallCheck(character, aimPart) then return nil end

	return Scorers[Config.Mode](root, screenPos, myRoot), aimPart, humanoid, root
end

local lockedPlayer = nil
local lastTarget = nil

local function getBestTarget(myRoot)
	local limitByFov = usesFov()
	local fovCenter = getFovCenter()

	if Config.Sticky and lockedPlayer then
		local score, part, humanoid, root = evaluate(lockedPlayer, myRoot, fovCenter, false)
		if score then
			return lockedPlayer, part, humanoid, root
		end
		lockedPlayer = nil
	end

	local bestPlayer, bestPart, bestHumanoid, bestRoot = nil, nil, nil, nil
	local bestScore = math.huge

	for _, other in ipairs(Players:GetPlayers()) do
		local score, part, humanoid, root = evaluate(other, myRoot, fovCenter, limitByFov)
		if score and score < bestScore then
			bestScore = score
			bestPlayer, bestPart, bestHumanoid, bestRoot = other, part, humanoid, root
		end
	end

	return bestPlayer, bestPart, bestHumanoid, bestRoot
end

local function getAimPosition(part, root)
	if Config.Prediction <= 0 then return part.Position end
	return part.Position + root.AssemblyLinearVelocity * Config.Prediction
end

local gui = Instance.new("ScreenGui")
gui.Name = "HakonGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = ACCENT_COLOR
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.15
fovStroke.Parent = fovCircle

local function updateFovCircle()
	local center = getFovCenter()
	fovCircle.Visible = Config.Enabled and Config.ShowFov and usesFov()
	fovCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
	fovCircle.Position = UDim2.fromOffset(center.X, center.Y)
end

local hud = Instance.new("Frame")
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 56)
hud.Size = UDim2.fromOffset(240, 46)
hud.BackgroundColor3 = BG_COLOR
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
hud.Visible = false
hud.ZIndex = 3
hud.Parent = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 10)

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = ACCENT_COLOR
hudStroke.Transparency = 0.5
hudStroke.Parent = hud

local hudName = Instance.new("TextLabel")
hudName.BackgroundTransparency = 1
hudName.Position = UDim2.fromOffset(10, 4)
hudName.Size = UDim2.new(1, -20, 0, 22)
hudName.Font = Enum.Font.GothamBold
hudName.TextSize = 14
hudName.TextColor3 = TEXT_COLOR
hudName.TextXAlignment = Enum.TextXAlignment.Left
hudName.Parent = hud

local hudBar = Instance.new("Frame")
hudBar.Position = UDim2.fromOffset(10, 32)
hudBar.Size = UDim2.new(1, -20, 0, 8)
hudBar.BackgroundColor3 = OFF_COLOR
hudBar.BorderSizePixel = 0
hudBar.Parent = hud
Instance.new("UICorner", hudBar).CornerRadius = UDim.new(1, 0)

local hudFill = Instance.new("Frame")
hudFill.Size = UDim2.fromScale(1, 1)
hudFill.BorderSizePixel = 0
hudFill.Parent = hudBar
Instance.new("UICorner", hudFill).CornerRadius = UDim.new(1, 0)

local function setHud(other, humanoid, root, myRoot)
	if not (Config.TargetHud and other) then
		hud.Visible = false
		return
	end
	local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local distance = math.floor((root.Position - myRoot.Position).Magnitude)
	hudName.Text = other.DisplayName .. "  ·  " .. distance .. " studs"
	hudFill.Size = UDim2.fromScale(ratio, 1)
	hudFill.BackgroundColor3 = healthColor(ratio)
	hud.Visible = true
end

local espFolder = Instance.new("Folder")
espFolder.Name = "HakonESP"
espFolder.Parent = player:WaitForChild("PlayerGui")

local esp = {}

local function createEsp(other)
	local entry = {}

	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = ACCENT_COLOR
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.Enabled = false
	highlight.Parent = espFolder
	entry.highlight = highlight

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(130, 40)
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.AlwaysOnTop = true
	billboard.ResetOnSpawn = false
	billboard.Enabled = false
	billboard.Parent = espFolder
	entry.billboard = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = TEXT_COLOR
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = billboard
	entry.name = nameLabel

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 15, 0, 19)
	bar.Size = UDim2.new(1, -30, 0, 5)
	bar.BackgroundColor3 = OFF_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = billboard
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	entry.fill = fill

	local distLabel = Instance.new("TextLabel")
	distLabel.BackgroundTransparency = 1
	distLabel.Position = UDim2.fromOffset(0, 26)
	distLabel.Size = UDim2.new(1, 0, 0, 12)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 11
	distLabel.TextColor3 = MUTED_COLOR
	distLabel.TextStrokeTransparency = 0.5
	distLabel.Parent = billboard
	entry.dist = distLabel

	local tracer = Instance.new("Frame")
	tracer.AnchorPoint = Vector2.new(0.5, 0.5)
	tracer.BackgroundColor3 = ACCENT_COLOR
	tracer.BorderSizePixel = 0
	tracer.Visible = false
	tracer.ZIndex = 1
	tracer.Parent = gui
	entry.tracer = tracer

	esp[other] = entry
	return entry
end

local function updateESP()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local view = camera.ViewportSize
	local origin = Vector2.new(view.X / 2, view.Y)

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local entry = esp[other] or createEsp(other)
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local valid = humanoid ~= nil
				and root ~= nil
				and humanoid.Health > 0
				and passesTeamCheck(other)

			local showBox = Config.ESP and valid
			entry.highlight.Adornee = showBox and character or nil
			entry.highlight.Enabled = showBox

			local showInfo = Config.ESPInfo and valid
			entry.billboard.Enabled = showInfo
			if showInfo then
				entry.billboard.Adornee = character:FindFirstChild("Head") or root
				entry.name.Text = other.DisplayName
				local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				entry.fill.Size = UDim2.fromScale(ratio, 1)
				entry.fill.BackgroundColor3 = healthColor(ratio)
				if myRoot then
					entry.dist.Text = math.floor((root.Position - myRoot.Position).Magnitude) .. " studs"
				end
			end

			local tracerVisible = false
			if Config.Tracers and valid then
				local pos, onScreen = toScreen(root.Position)
				if onScreen then
					local delta = pos - origin
					entry.tracer.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
					entry.tracer.Position = UDim2.fromOffset((pos.X + origin.X) / 2, (pos.Y + origin.Y) / 2)
					entry.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					tracerVisible = true
				end
			end
			entry.tracer.Visible = tracerVisible
		end
	end
end

Players.PlayerRemoving:Connect(function(other)
	local entry = esp[other]
	if entry then
		entry.highlight:Destroy()
		entry.billboard:Destroy()
		entry.tracer:Destroy()
		esp[other] = nil
	end
	if lockedPlayer == other then
		lockedPlayer = nil
	end
end)

local function isAiming()
	if not Config.Enabled then return false end
	if Config.HoldToAim then
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end
	return true
end

local function updateCamera()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if not isAiming() or not myRoot then
		lastTarget = nil
		lockedPlayer = nil
		setHud(nil)
		return
	end

	local other, part, humanoid, root = getBestTarget(myRoot)
	if not other then
		lastTarget = nil
		setHud(nil)
		return
	end

	if other ~= lastTarget then
		lastTarget = other
		playSound("Lock")
	end
	lockedPlayer = Config.Sticky and other or nil

	setHud(other, humanoid, root, myRoot)

	local goal = CFrame.lookAt(camera.CFrame.Position, getAimPosition(part, root))
	local alpha = math.clamp(1 - Config.Smoothing, 0.05, 1)
	camera.CFrame = camera.CFrame:Lerp(goal, alpha)
end

local function bindDrag(handle, onBegin, onMove, onEnd)
	local activeInput = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			activeInput = input
			onBegin(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not activeInput then return end
		local isMouseDrag = activeInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if isMouseDrag or input == activeInput then
			onMove(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not activeInput then return end
		local sameMouse = activeInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseButton1
		if sameMouse or input == activeInput then
			activeInput = nil
			if onEnd then onEnd() end
		end
	end)
end

local DEFAULT_SIZE = Vector2.new(290, 400)
local DEFAULT_POSITION = Vector2.new(12, 80)
local MIN_SIZE = Vector2.new(250, 240)
local MAX_SIZE = Vector2.new(480, 600)
local HEADER_HEIGHT = 36
local TAB_HEIGHT = 30
local MINIMIZED_WIDTH = 150

local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.fromOffset(DEFAULT_SIZE.X, DEFAULT_SIZE.Y)
window.Position = UDim2.fromOffset(DEFAULT_POSITION.X, DEFAULT_POSITION.Y)
window.BackgroundColor3 = BG_COLOR
window.BackgroundTransparency = 0.05
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.ZIndex = 5
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 12)

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = ACCENT_COLOR
windowStroke.Transparency = 0.55
windowStroke.Thickness = 1
windowStroke.Parent = window

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = HEADER_COLOR
header.BorderSizePixel = 0
header.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.RichText = true
title.Text = 'HAKON  <font size="11" color="rgb(125,195,255)">by 777</font>'
title.TextColor3 = TEXT_COLOR
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.fromOffset(30, 26)
minimizeBtn.Position = UDim2.new(1, -38, 0.5, -13)
minimizeBtn.BackgroundColor3 = OFF_COLOR
minimizeBtn.TextColor3 = TEXT_COLOR
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Text = "-"
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = header
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 7)

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
body.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
body.BackgroundTransparency = 1
body.Parent = window

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, TAB_HEIGHT + 6)
tabBar.BackgroundTransparency = 1
tabBar.Parent = body

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft = UDim.new(0, 6)
tabPadding.PaddingRight = UDim.new(0, 6)
tabPadding.PaddingTop = UDim.new(0, 6)
tabPadding.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local pagesHolder = Instance.new("Frame")
pagesHolder.Position = UDim2.fromOffset(6, TAB_HEIGHT + 12)
pagesHolder.Size = UDim2.new(1, -12, 1, -(TAB_HEIGHT + 18))
pagesHolder.BackgroundTransparency = 1
pagesHolder.Parent = body

local resizeHandle = Instance.new("TextLabel")
resizeHandle.AnchorPoint = Vector2.new(1, 1)
resizeHandle.Size = UDim2.fromOffset(26, 26)
resizeHandle.Position = UDim2.new(1, -2, 1, -2)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Text = "◢"
resizeHandle.TextColor3 = ACCENT_COLOR
resizeHandle.TextSize = 16
resizeHandle.ZIndex = 8
resizeHandle.Active = true
resizeHandle.Parent = window

local expandedSize = DEFAULT_SIZE
local minimized = false

local function clampPosition(x, y)
	local view = camera.ViewportSize
	local width = window.AbsoluteSize.X
	x = math.clamp(x, -width + 70, view.X - 70)
	y = math.clamp(y, 0, view.Y - HEADER_HEIGHT)
	return x, y
end

do
	local startPoint, startPos
	bindDrag(header, function(point)
		startPoint = point
		startPos = Vector2.new(window.Position.X.Offset, window.Position.Y.Offset)
	end, function(point)
		local delta = point - startPoint
		local x, y = clampPosition(startPos.X + delta.X, startPos.Y + delta.Y)
		window.Position = UDim2.fromOffset(x, y)
	end)
end

do
	local startPoint, startSize
	bindDrag(resizeHandle, function(point)
		startPoint = point
		startSize = expandedSize
	end, function(point)
		local delta = point - startPoint
		local width = math.clamp(startSize.X + delta.X, MIN_SIZE.X, MAX_SIZE.X)
		local height = math.clamp(startSize.Y + delta.Y, MIN_SIZE.Y, MAX_SIZE.Y)
		expandedSize = Vector2.new(width, height)
		window.Size = UDim2.fromOffset(width, height)
	end)
end

local function setMinimized(state)
	minimized = state
	minimizeBtn.Text = state and "+" or "-"
	resizeHandle.Visible = not state
	body.Visible = not state
	local goal = state and Vector2.new(MINIMIZED_WIDTH, HEADER_HEIGHT) or expandedSize
	TweenService:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(goal.X, goal.Y),
	}):Play()
end

minimizeBtn.MouseButton1Click:Connect(function()
	playSound("Click")
	setMinimized(not minimized)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		window.Visible = not window.Visible
		playSound("Click")
	end
end)

local pages = {}
local tabButtons = {}
local backgrounds = {}

local function selectTab(name)
	for pageName, container in pairs(pages) do
		local active = pageName == name
		container.Visible = active
		TweenService:Create(tabButtons[pageName], TweenInfo.new(0.15), {
			BackgroundColor3 = active and ACCENT_COLOR or OFF_COLOR,
			TextColor3 = active and DARK_TEXT or TEXT_COLOR,
		}):Play()
	end
end

local function createPage(name, label, order, image)
	local tab = Instance.new("TextButton")
	tab.Size = UDim2.new(0.25, -3, 1, 0)
	tab.BackgroundColor3 = OFF_COLOR
	tab.TextColor3 = TEXT_COLOR
	tab.Font = Enum.Font.GothamMedium
	tab.TextSize = 12
	tab.Text = label
	tab.AutoButtonColor = false
	tab.LayoutOrder = order
	tab.Parent = tabBar
	Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 7)
	tabButtons[name] = tab

	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = BG_COLOR
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Visible = false
	container.Parent = pagesHolder
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 9)
	pages[name] = container

	if image ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = image
		img.ScaleType = Enum.ScaleType.Crop
		img.ImageTransparency = 1 - Config.BgOpacity
		img.Parent = container
		Instance.new("UICorner", img).CornerRadius = UDim.new(0, 9)
		table.insert(backgrounds, img)
	end

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = BG_COLOR
	shade.BackgroundTransparency = 0.5
	shade.BorderSizePixel = 0
	shade.Parent = container

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = ACCENT_COLOR
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 28)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	tab.MouseButton1Click:Connect(function()
		playSound("Click")
		selectTab(name)
	end)

	return scroll
end

local function createButton(parent, text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = OFF_COLOR
	btn.BackgroundTransparency = 0.15
	btn.TextColor3 = TEXT_COLOR
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 14
	btn.Text = text
	btn.AutoButtonColor = false
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	return btn
end

local function createSection(parent, text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.TextColor3 = ACCENT_COLOR
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeTransparency = 0.6
	label.Text = string.upper(text)
	label.Parent = parent
	return label
end

local function createToggle(parent, label, key, onChange)
	local btn = createButton(parent, label)
	btn.TextXAlignment = Enum.TextXAlignment.Left

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = btn

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -10, 0.5, 0)
	track.Size = UDim2.fromOffset(38, 20)
	track.BorderSizePixel = 0
	track.Parent = btn
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(14, 14)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh(animate)
		local on = Config[key]
		local info = TweenInfo.new(animate and 0.15 or 0)
		TweenService:Create(track, info, {
			BackgroundColor3 = on and ACCENT_COLOR or TRACK_OFF,
		}):Play()
		TweenService:Create(knob, info, {
			Position = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		}):Play()
	end

	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		refresh(true)
		playSound(Config[key] and "On" or "Off")
		if onChange then onChange() end
	end)

	refresh(false)
	return btn
end

local function createChoice(parent, key, options, onChange)
	local buttons = {}

	local function refresh()
		for value, btn in pairs(buttons) do
			local active = Config[key] == value
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundColor3 = active and ACCENT_COLOR or OFF_COLOR,
				TextColor3 = active and DARK_TEXT or TEXT_COLOR,
			}):Play()
		end
	end

	for _, option in ipairs(options) do
		local btn = createButton(parent, option.label)
		buttons[option.value] = btn
		btn.MouseButton1Click:Connect(function()
			Config[key] = option.value
			playSound("Click")
			refresh()
			if onChange then onChange() end
		end)
	end

	refresh()
end

local function createSlider(parent, label, min, max, key, formatFn, onChange)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 46)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 18)
	text.BackgroundTransparency = 1
	text.TextColor3 = TEXT_COLOR
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 13
	text.TextStrokeTransparency = 0.6
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = holder

	local bar = Instance.new("TextButton")
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Position = UDim2.fromOffset(0, 26)
	bar.Size = UDim2.new(1, 0, 0, 14)
	bar.BackgroundColor3 = OFF_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = holder
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local alpha = (Config[key] - min) / (max - min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		text.Text = label .. ": " .. formatFn(Config[key])
	end

	local function setFromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		Config[key] = min + (max - min) * alpha
		refresh()
		if onChange then onChange() end
	end

	bindDrag(bar, function(point)
		parent.ScrollingEnabled = false
		setFromX(point.X)
	end, function(point)
		setFromX(point.X)
	end, function()
		parent.ScrollingEnabled = true
	end)

	refresh()
	return holder
end

local aimPage = createPage("aim", "Mira", 1, Assets.Aim)
local targetPage = createPage("target", "Alvo", 2, Assets.Target)
local visualPage = createPage("visual", "Visual", 3, Assets.Visual)
local settingsPage = createPage("settings", "Config", 4, Assets.Settings)

createSection(aimPage, "Assistência")
createToggle(aimPage, "Ativar", "Enabled")
createToggle(aimPage, "Só com botão direito", "HoldToAim")
createToggle(aimPage, "Alvo fixo", "Sticky")
createSection(aimPage, "Filtros")
createToggle(aimPage, "Team Check", "TeamCheck")
createToggle(aimPage, "Wall Check", "WallCheck")
createToggle(aimPage, "Alive Check", "AliveCheck")
createSection(aimPage, "Parte do corpo")
createChoice(aimPage, "AimPart", {
	{ value = "Head", label = "Cabeça" },
	{ value = "HumanoidRootPart", label = "Torso" },
})
createSection(aimPage, "Movimento")
createSlider(aimPage, "Suavização", 0, 0.95, "Smoothing", function(v)
	return math.floor(v * 100) .. "%"
end)
createSlider(aimPage, "Predição", 0, 0.3, "Prediction", function(v)
	return string.format("%.2f s", v)
end)

local fovToggle, fovSlider

local function refreshFovGroup()
	local visible = usesFov()
	fovToggle.Visible = visible
	fovSlider.Visible = visible
end

createSection(targetPage, "Modo de seleção")
createChoice(targetPage, "Mode", {
	{ value = "Proximity", label = "Proximidade" },
	{ value = "ScreenCenter", label = "Centro da Tela" },
	{ value = "Mouse", label = "Cursor do Mouse" },
}, refreshFovGroup)
createSection(targetPage, "Alcance")
fovToggle = createToggle(targetPage, "Mostrar círculo FOV", "ShowFov")
fovSlider = createSlider(targetPage, "FOV", 30, 500, "FOV", function(v)
	return math.floor(v) .. " px"
end)
createSlider(targetPage, "Distância máx.", 50, 3000, "MaxDistance", function(v)
	return math.floor(v) .. " studs"
end)
createToggle(targetPage, "Painel do alvo", "TargetHud")
refreshFovGroup()

createSection(visualPage, "ESP")
createToggle(visualPage, "Contorno (através de paredes)", "ESP")
createToggle(visualPage, "Nome, vida e distância", "ESPInfo")
createToggle(visualPage, "Linhas até os alvos", "Tracers")

createSection(settingsPage, "Áudio")
createToggle(settingsPage, "Sons", "Sounds")
createSlider(settingsPage, "Volume", 0, 1, "Volume", function(v)
	return math.floor(v * 100) .. "%"
end)
createSection(settingsPage, "Aparência")
createSlider(settingsPage, "Fundo", 0, 1, "BgOpacity", function(v)
	return math.floor(v * 100) .. "%"
end, function()
	for _, img in ipairs(backgrounds) do
		img.ImageTransparency = 1 - Config.BgOpacity
	end
end)

local resetBtn = createButton(settingsPage, "Resetar janela")
resetBtn.MouseButton1Click:Connect(function()
	playSound("Click")
	expandedSize = DEFAULT_SIZE
	window.Position = UDim2.fromOffset(DEFAULT_POSITION.X, DEFAULT_POSITION.Y)
	setMinimized(false)
end)

createSection(settingsPage, "Atalhos")
local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 30)
hint.BackgroundTransparency = 1
hint.TextColor3 = MUTED_COLOR
hint.Font = Enum.Font.Gotham
hint.TextSize = 12
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.TextStrokeTransparency = 0.6
hint.Text = "RightShift abre e fecha o menu"
hint.Parent = settingsPage

local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(1, 0, 0, 30)
credit.BackgroundTransparency = 1
credit.TextColor3 = ACCENT_COLOR
credit.Font = Enum.Font.GothamBold
credit.TextSize = 12
credit.TextWrapped = true
credit.TextXAlignment = Enum.TextXAlignment.Left
credit.TextYAlignment = Enum.TextYAlignment.Top
credit.TextStrokeTransparency = 0.6
credit.Text = "Feito por 777 · Discord: 777.imt"
credit.Parent = settingsPage

selectTab("aim")

RunService:BindToRenderStep("HakonAim", Enum.RenderPriority.Camera.Value + 1, function()
	camera = workspace.CurrentCamera
	updateFovCircle()
	updateCamera()
	updateESP()
end)
