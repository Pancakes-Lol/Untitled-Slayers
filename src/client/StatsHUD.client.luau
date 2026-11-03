-- Placeholder three-stat upgrade GUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local statsFolder = player:WaitForChild("Stats")
local statPoints = statsFolder:WaitForChild("StatPoints")
local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeStat")

local assets = ReplicatedStorage:WaitForChild("Assets")
local configs = assets:WaitForChild("Configs")
local StatConfig = require(configs:WaitForChild("StatConfig"))

local oldGui = playerGui:FindFirstChild("StatsPlaceholderUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "StatsPlaceholderUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(parent, radius)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius or 8)
	uiCorner.Parent = parent
end

local function stroke(parent, transparency)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 1.5
	uiStroke.Transparency = transparency or 0.35
	uiStroke.Parent = parent
end

local openButton = Instance.new("TextButton")
openButton.Name = "StatsButton"
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -20, 0.5, 0)
openButton.Size = UDim2.fromOffset(92, 38)
openButton.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 16
openButton.Text = "STATS"
openButton.Parent = gui
corner(openButton, 8)
stroke(openButton, 0.4)

local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -20, 0.5, 0)
panel.Size = UDim2.fromOffset(330, 270)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
corner(panel, 10)
stroke(panel, 0.25)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -70, 0, 30)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "STATS"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.fromOffset(34, 30)
closeButton.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = panel
corner(closeButton, 7)

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "PointsLabel"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Position = UDim2.fromOffset(18, 48)
pointsLabel.Size = UDim2.new(1, -36, 0, 26)
pointsLabel.Font = Enum.Font.GothamMedium
pointsLabel.TextSize = 17
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
pointsLabel.Parent = panel

local note = Instance.new("TextLabel")
note.Name = "Note"
note.BackgroundTransparency = 1
note.Position = UDim2.fromOffset(18, 76)
note.Size = UDim2.new(1, -36, 0, 22)
note.Font = Enum.Font.Gotham
note.TextSize = 13
note.TextXAlignment = Enum.TextXAlignment.Left
note.TextColor3 = Color3.fromRGB(170, 170, 180)
note.Text = "Each upgrade costs 1 point"
note.Parent = panel

local ordered = {}
for statId, definition in pairs(StatConfig) do
	if type(definition) == "table" then
		table.insert(ordered, {Id = statId, Definition = definition})
	end
end
table.sort(ordered, function(a, b)
	return (tonumber(a.Definition.Order) or 999) < (tonumber(b.Definition.Order) or 999)
end)

local rowBindings = {}
for index, entry in ipairs(ordered) do
	local statId = entry.Id
	local definition = entry.Definition
	local value = statsFolder:WaitForChild(statId)

	local row = Instance.new("Frame")
	row.Name = statId .. "Row"
	row.Position = UDim2.fromOffset(18, 106 + ((index - 1) * 50))
	row.Size = UDim2.new(1, -36, 0, 42)
	row.BackgroundColor3 = Color3.fromRGB(29, 29, 35)
	row.Parent = panel
	corner(row, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 0)
	nameLabel.Size = UDim2.new(0.58, 0, 1, 0)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = tostring(definition.DisplayName or statId)
	nameLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "ValueLabel"
	valueLabel.BackgroundTransparency = 1
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -54, 0, 0)
	valueLabel.Size = UDim2.fromOffset(64, 42)
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 16
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
	valueLabel.Parent = row

	local plus = Instance.new("TextButton")
	plus.Name = "UpgradeButton"
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -7, 0.5, 0)
	plus.Size = UDim2.fromOffset(36, 30)
	plus.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	plus.TextColor3 = Color3.new(1, 1, 1)
	plus.Font = Enum.Font.GothamBold
	plus.TextSize = 22
	plus.Text = "+"
	plus.Parent = row
	corner(plus, 7)

	plus.Activated:Connect(function()
		if statPoints.Value <= 0 then return end
		upgradeRemote:FireServer(statId)
	end)

	local function refreshRow()
		valueLabel.Text = tostring(value.Value)
		plus.Active = statPoints.Value > 0
		plus.AutoButtonColor = statPoints.Value > 0
		plus.TextTransparency = statPoints.Value > 0 and 0 or 0.55
	end
	value:GetPropertyChangedSignal("Value"):Connect(refreshRow)
	rowBindings[index] = refreshRow
end

local function refreshAll()
	pointsLabel.Text = "Available Points: " .. tostring(statPoints.Value)
	for _, refreshRow in ipairs(rowBindings) do
		refreshRow()
	end
end

statPoints:GetPropertyChangedSignal("Value"):Connect(refreshAll)

openButton.Activated:Connect(function()
	openButton.Visible = false
	panel.Visible = true
end)

closeButton.Activated:Connect(function()
	panel.Visible = false
	openButton.Visible = true
end)

refreshAll()
