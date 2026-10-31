-- Compact currency readout for the existing bottom-left currency area.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local currency = player:WaitForChild("Currency")
local coins = currency:WaitForChild("Coins")
local gems = currency:WaitForChild("Gems")

local gui = Instance.new("ScreenGui")
gui.Name = "CurrencyLabels"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.Name = "CurrencyHolder"
holder.AnchorPoint = Vector2.new(0, 1)
holder.Position = UDim2.new(0, 18, 1, -18)
holder.Size = UDim2.fromOffset(210, 48)
holder.BackgroundTransparency = 1
holder.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 14)
layout.Parent = holder

local function makeCurrency(name, valueObject)
	local item = Instance.new("Frame")
	item.Name = name
	item.Size = UDim2.fromOffset(92, 44)
	item.BackgroundTransparency = 1
	item.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Size = UDim2.new(1, 0, 0, 28)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 18
	value.TextColor3 = Color3.fromRGB(245, 247, 255)
	value.TextStrokeTransparency = 0.55
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.Parent = item

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 27)
	label.Size = UDim2.new(1, 0, 0, 13)
	label.Font = Enum.Font.GothamMedium
	label.Text = string.upper(name)
	label.TextSize = 9
	label.TextColor3 = Color3.fromRGB(175, 181, 198)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = item

	local function refresh()
		value.Text = tostring(valueObject.Value)
	end
	valueObject:GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end

makeCurrency("Coins", coins)
makeCurrency("Gems", gems)
