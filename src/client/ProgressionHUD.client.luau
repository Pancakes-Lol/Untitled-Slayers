local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local stats = player:WaitForChild("leaderstats")
local level = stats:WaitForChild("Level")
local xp = stats:WaitForChild("XP")

local function xpNeededForLevel(currentLevel)
	return 100 + math.max(0, currentLevel - 1) * 50
end

local gui = Instance.new("ScreenGui")
gui.Name = "ProgressionHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "LevelCard"
card.AnchorPoint = Vector2.new(1, 1)
card.Position = UDim2.new(1, -18, 1, -18)
card.Size = UDim2.fromOffset(330, 74)
card.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = gui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 14)
cardCorner.Parent = card

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.45
stroke.Color = Color3.fromRGB(120, 126, 150)
stroke.Parent = card

local levelBadge = Instance.new("Frame")
levelBadge.Name = "LevelBadge"
levelBadge.Position = UDim2.fromOffset(12, 12)
levelBadge.Size = UDim2.fromOffset(50, 50)
levelBadge.BackgroundColor3 = Color3.fromRGB(48, 52, 70)
levelBadge.BorderSizePixel = 0
levelBadge.Parent = card

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = levelBadge

local levelSmall = Instance.new("TextLabel")
levelSmall.BackgroundTransparency = 1
levelSmall.Position = UDim2.fromOffset(0, 5)
levelSmall.Size = UDim2.new(1, 0, 0, 13)
levelSmall.Font = Enum.Font.GothamMedium
levelSmall.Text = "LEVEL"
levelSmall.TextSize = 9
levelSmall.TextColor3 = Color3.fromRGB(170, 176, 196)
levelSmall.Parent = levelBadge

local levelNumber = Instance.new("TextLabel")
levelNumber.BackgroundTransparency = 1
levelNumber.Position = UDim2.fromOffset(0, 15)
levelNumber.Size = UDim2.new(1, 0, 1, -16)
levelNumber.Font = Enum.Font.GothamBold
levelNumber.TextSize = 22
levelNumber.TextColor3 = Color3.fromRGB(245, 247, 255)
levelNumber.Parent = levelBadge

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(74, 11)
title.Size = UDim2.new(1, -86, 0, 20)
title.Font = Enum.Font.GothamSemibold
title.Text = "Slayer Progress"
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(242, 244, 252)
title.Parent = card

local xpText = Instance.new("TextLabel")
xpText.BackgroundTransparency = 1
xpText.Position = UDim2.new(1, -118, 0, 12)
xpText.Size = UDim2.fromOffset(106, 18)
xpText.Font = Enum.Font.GothamMedium
xpText.TextSize = 11
xpText.TextXAlignment = Enum.TextXAlignment.Right
xpText.TextColor3 = Color3.fromRGB(172, 178, 197)
xpText.Parent = card

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(74, 42)
barBack.Size = UDim2.new(1, -88, 0, 12)
barBack.BackgroundColor3 = Color3.fromRGB(39, 43, 56)
barBack.BorderSizePixel = 0
barBack.ClipsDescendants = true
barBack.Parent = card

local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(1, 0)
backCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(129, 105, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

local gradient = Instance.new("UIGradient")
gradient.Rotation = 0
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 118, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(164, 98, 255)),
})
gradient.Parent = barFill

local subText = Instance.new("TextLabel")
subText.BackgroundTransparency = 1
subText.Position = UDim2.fromOffset(74, 56)
subText.Size = UDim2.new(1, -88, 0, 12)
subText.Font = Enum.Font.Gotham
subText.Text = "Earn XP by defeating enemies"
subText.TextSize = 9
subText.TextXAlignment = Enum.TextXAlignment.Left
subText.TextColor3 = Color3.fromRGB(128, 134, 153)
subText.Parent = card

local activeTween
local function refresh(instant)
	local needed = xpNeededForLevel(level.Value)
	local ratio = needed > 0 and math.clamp(xp.Value / needed, 0, 1) or 0
	levelNumber.Text = tostring(level.Value)
	xpText.Text = string.format("%d / %d XP", xp.Value, needed)

	if activeTween then activeTween:Cancel() end
	if instant then
		barFill.Size = UDim2.new(ratio, 0, 1, 0)
	else
		activeTween = TweenService:Create(
			barFill,
			TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(ratio, 0, 1, 0)}
		)
		activeTween:Play()
	end
end

level:GetPropertyChangedSignal("Value"):Connect(function()
	refresh(false)
end)

xp:GetPropertyChangedSignal("Value"):Connect(function()
	refresh(false)
end)

refresh(true)
