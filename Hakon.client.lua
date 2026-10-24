local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = {
	Enabled = false,
	TeamCheck = false,
	WallCheck = false,
	AliveCheck = true,
	ESP = false,
	AimPart = "Head",
	Mode = "Proximity",
	FOV = 150,
	Smoothing = 0.5,
	MaxDistance = 1000,
}

local MODES = { "Proximity", "ScreenCenter", "Mouse" }
local MODE_LABELS = {
	Proximity = "Modo: Proximidade",
	ScreenCenter = "Modo: Centro da Tela",
	Mouse = "Modo: Cursor do Mouse",
}
local PART_LABELS = {
	Head = "Alvo: Cabeça",
	HumanoidRootPart = "Alvo: Torso",
}

local gui

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

function Scorers.Proximity(root)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	return (root.Position - myRoot.Position).Magnitude
end

function Scorers.ScreenCenter(_, screenPos)
	return (screenPos - getScreenCenter()).Magnitude
end

function Scorers.Mouse(_, screenPos)
	return (screenPos - UserInputService:GetMouseLocation()).Magnitude
end

local function getBestTarget()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local fovCenter = getFovCenter()
	local bestPart, bestScore = nil, math.huge

	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if other ~= player and character and passesTeamCheck(other) then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			local aimPart = character:FindFirstChild(Config.AimPart) or root

			if humanoid and root and aimPart and passesAliveCheck(humanoid) then
				if (root.Position - myRoot.Position).Magnitude <= Config.MaxDistance then
					local screenPos, onScreen = toScreen(aimPart.Position)

					if onScreen and (screenPos - fovCenter).Magnitude <= Config.FOV then
						if passesWallCheck(character, aimPart) then
							local score = Scorers[Config.Mode](root, screenPos)
							if score and score < bestScore then
								bestScore = score
								bestPart = aimPart
							end
						end
					end
				end
			end
		end
	end

	return bestPart
end

local function updateCamera()
	if not Config.Enabled then return end

	local target = getBestTarget()
	if not target then return end

	local goal = CFrame.lookAt(camera.CFrame.Position, target.Position)
	local alpha = math.clamp(1 - Config.Smoothing, 0.05, 1)
	camera.CFrame = camera.CFrame:Lerp(goal, alpha)
end

local highlights = {}

local function getHighlight(other)
	local existing = highlights[other]
	if existing and existing.Parent then return existing end

	local h = Instance.new("Highlight")
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillColor = Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.7
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.OutlineTransparency = 0
	h.Enabled = false
	h.Parent = gui or player:WaitForChild("PlayerGui")
	highlights[other] = h
	return h
end

local function updateESP()
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local h = getHighlight(other)
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			local visible = Config.ESP
				and character ~= nil
				and humanoid ~= nil
				and humanoid.Health > 0
				and passesTeamCheck(other)

			h.Adornee = visible and character or nil
			h.Enabled = visible
		end
	end
end

Players.PlayerRemoving:Connect(function(other)
	if highlights[other] then
		highlights[other]:Destroy()
		highlights[other] = nil
	end
end)

gui = Instance.new("ScreenGui")
gui.Name = "AimAssistGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local ON_COLOR = Color3.fromRGB(60, 160, 90)
local OFF_COLOR = Color3.fromRGB(70, 70, 80)

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.new(1, 1, 1)
fovStroke.Thickness = 1.5
fovStroke.Parent = fovCircle

local function updateFovCircle()
	local center = getFovCenter()
	fovCircle.Visible = Config.Enabled
	fovCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
	fovCircle.Position = UDim2.fromOffset(center.X, center.Y)
end

local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(220, 410)
menu.Position = UDim2.new(0, 10, 0.5, -205)
menu.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
menu.BorderSizePixel = 0
menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 10)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = menu

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = menu

local function createButton(text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = OFF_COLOR
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 14
	btn.Text = text
	btn.Parent = menu
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	return btn
end

local function createToggle(label, key)
	local btn = createButton(label .. ": OFF")
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		btn.Text = label .. ": " .. (Config[key] and "ON" or "OFF")
		btn.BackgroundColor3 = Config[key] and ON_COLOR or OFF_COLOR
	end)
	if Config[key] then
		btn.Text = label .. ": ON"
		btn.BackgroundColor3 = ON_COLOR
	end
	return btn
end

local function createSlider(label, min, max, key, formatFn)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 40)
	holder.BackgroundTransparency = 1
	holder.Parent = menu

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 18)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.Gotham
	text.TextSize = 13
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = holder

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.BackgroundColor3 = OFF_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = holder
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ON_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local alpha = (Config[key] - min) / (max - min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		text.Text = label .. ": " .. formatFn(Config[key])
	end

	local dragging = false
	local function setFromX(x)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		Config[key] = min + (max - min) * alpha
		refresh()
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	refresh()
end

createToggle("Assistência", "Enabled")
createToggle("Team Check", "TeamCheck")
createToggle("Wall Check", "WallCheck")
createToggle("Alive Check", "AliveCheck")
createToggle("ESP", "ESP")

local partBtn = createButton(PART_LABELS[Config.AimPart])
partBtn.MouseButton1Click:Connect(function()
	Config.AimPart = (Config.AimPart == "Head") and "HumanoidRootPart" or "Head"
	partBtn.Text = PART_LABELS[Config.AimPart]
end)

local modeBtn = createButton(MODE_LABELS[Config.Mode])
modeBtn.MouseButton1Click:Connect(function()
	local index = table.find(MODES, Config.Mode) or 1
	Config.Mode = MODES[(index % #MODES) + 1]
	modeBtn.Text = MODE_LABELS[Config.Mode]
end)

createSlider("FOV", 30, 500, "FOV", function(v) return math.floor(v) .. " px" end)
createSlider("Suavização", 0, 0.95, "Smoothing", function(v) return math.floor(v * 100) .. "%" end)

RunService:BindToRenderStep("AimAssist", Enum.RenderPriority.Camera.Value + 1, function()
	updateFovCircle()
	updateCamera()
end)

RunService.Heartbeat:Connect(updateESP)
