-- Placeholder combat stat allocation UI.
-- This UI is intentionally simple so the visuals can be replaced later without changing progression logic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local stats = player:WaitForChild("Stats")
local statPoints = stats:WaitForChild("StatPoints")
local agility = stats:WaitForChild("Agility")
local defense = stats:WaitForChild("Defense")
local attack = stats:WaitForChild("Attack")
local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeStat")

local oldGui = playerGui:FindFirstChild("StatsUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "StatsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local toggle = Instance.new("TextButton")
toggle.Name = "StatsToggle"
toggle.AnchorPoint = Vector2.new(0, 0.5)
toggle.Position = UDim2.new(0, 18, 0.5, -105)
toggle.Size = UDim2.fromOffset(92, 34)
toggle.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
toggle.BorderSizePixel = 0
toggle.Text = "STATS"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 15
toggle.Parent = gui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 7)
toggleCorner.Parent = toggle

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 18, 0.5, 35)
panel.Size = UDim2.fromOffset(340, 300)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Transparency = 0.35
stroke.Thickness = 1
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(16, 12)
title.Size = UDim2.new(1, -32, 0, 28)
title.Text = "STAT ALLOCATION"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "PointsLabel"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Position = UDim2.fromOffset(16, 42)
pointsLabel.Size = UDim2.new(1, -32, 0, 24)
pointsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
pointsLabel.Font = Enum.Font.GothamMedium
pointsLabel.TextSize = 14
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.Parent = panel

local costLabel = Instance.new("TextLabel")
costLabel.BackgroundTransparency = 1
costLabel.Position = UDim2.fromOffset(16, 64)
costLabel.Size = UDim2.new(1, -32, 0, 20)
costLabel.Text = "Each upgrade costs 1 stat point"
costLabel.TextColor3 = Color3.fromRGB(170, 170, 176)
costLabel.Font = Enum.Font.Gotham
costLabel.TextSize = 12
costLabel.TextXAlignment = Enum.TextXAlignment.Left
costLabel.Parent = panel

local rows = {}

local function makeRow(index, statId, displayName, effectText)
	local y = 90 + ((index - 1) * 56)
	local row = Instance.new("Frame")
	row.Name = statId .. "Row"
	row.Position = UDim2.fromOffset(14, y)
	row.Size = UDim2.new(1, -28, 0, 48)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	row.BorderSizePixel = 0
	row.Parent = panel

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 7)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(10, 5)
	nameLabel.Size = UDim2.new(0.56, 0, 0, 20)
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local effectLabel = Instance.new("TextLabel")
	effectLabel.BackgroundTransparency = 1
	effectLabel.Position = UDim2.fromOffset(10, 25)
	effectLabel.Size = UDim2.new(0.68, 0, 0, 17)
	effectLabel.Text = effectText
	effectLabel.TextColor3 = Color3.fromRGB(168, 168, 175)
	effectLabel.Font = Enum.Font.Gotham
	effectLabel.TextSize = 11
	effectLabel.TextXAlignment = Enum.TextXAlignment.Left
	effectLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.BackgroundTransparency = 1
	valueLabel.AnchorPoint = Vector2.new(1, 0.5)
	valueLabel.Position = UDim2.new(1, -54, 0.5, 0)
	valueLabel.Size = UDim2.fromOffset(52, 28)
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 16
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = row

	local plus = Instance.new("TextButton")
	plus.Name = "Upgrade"
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -8, 0.5, 0)
	plus.Size = UDim2.fromOffset(36, 32)
	plus.BackgroundColor3 = Color3.fromRGB(52, 89, 58)
	plus.BorderSizePixel = 0
	plus.Text = "+"
	plus.TextColor3 = Color3.new(1, 1, 1)
	plus.Font = Enum.Font.GothamBold
	plus.TextSize = 20
	plus.Parent = row

	local plusCorner = Instance.new("UICorner")
	plusCorner.CornerRadius = UDim.new(0, 6)
	plusCorner.Parent = plus

	plus.Activated:Connect(function()
		if statPoints.Value > 0 then
			upgradeRemote:FireServer(statId)
		end
	end)

	rows[statId] = {
		value = valueLabel,
		button = plus,
	}
end

makeRow(1, "Agility", "Agility", "+0.5 movement speed per point")
makeRow(2, "Defense", "Defensive Stat", "+10 max health per point")
makeRow(3, "Attack", "Attack Stat", "+2 sword damage per point")

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.Position = UDim2.new(0, 16, 1, -28)
footer.Size = UDim2.new(1, -32, 0, 18)
footer.Text = "+2 stat points and +5 gems every level"
footer.TextColor3 = Color3.fromRGB(160, 160, 168)
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = panel

local function refresh()
	pointsLabel.Text = "Available Points: " .. tostring(statPoints.Value)
	rows.Agility.value.Text = tostring(agility.Value)
	rows.Defense.value.Text = tostring(defense.Value)
	rows.Attack.value.Text = tostring(attack.Value)

	local canUpgrade = statPoints.Value > 0
	for _, row in pairs(rows) do
		row.button.Active = canUpgrade
		row.button.AutoButtonColor = canUpgrade
		row.button.BackgroundTransparency = canUpgrade and 0 or 0.45
	end
end

statPoints:GetPropertyChangedSignal("Value"):Connect(refresh)
agility:GetPropertyChangedSignal("Value"):Connect(refresh)
defense:GetPropertyChangedSignal("Value"):Connect(refresh)
attack:GetPropertyChangedSignal("Value"):Connect(refresh)

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

refresh()
