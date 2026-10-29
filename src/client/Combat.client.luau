-- Untitled Slayers: F = Punch, G = Roundhouse Kick.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("CombatAction")
local moves = {
	Punch = {key = Enum.KeyCode.F, label = "PUNCH", cooldown = 0.42},
	Kick = {key = Enum.KeyCode.G, label = "ROUNDHOUSE KICK", cooldown = 0.82},
}
local nextReady = {Punch = 0, Kick = 0}
local lockedUntil = 0

local gui = Instance.new("ScreenGui")
gui.Name = "CombatKeybinds"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "CombatPanel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -22, 1, -24)
panel.Size = UDim2.fromOffset(228, 118)
panel.BackgroundColor3 = Color3.fromRGB(16, 19, 28)
panel.BackgroundTransparency = 0.12
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(75, 88, 120)
stroke.Thickness = 1

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(12, 6)
heading.Size = UDim2.new(1, -24, 0, 25)
heading.Font = Enum.Font.GothamBold
heading.TextSize = 14
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.TextColor3 = Color3.fromRGB(245, 245, 255)
heading.Text = "COMBAT MOVES"
heading.Parent = panel

local buttons = {}
local function createButton(move, y)
	local cfg = moves[move]
	local button = Instance.new("TextButton")
	button.Name = move
	button.Position = UDim2.fromOffset(12, y)
	button.Size = UDim2.new(1, -24, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(37, 44, 63)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 13
	button.Text = "[" .. cfg.key.Name .. "]   " .. cfg.label
	button.Parent = panel
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	buttons[move] = button
end
createButton("Punch", 35)
createButton("Kick", 75)

local function useMove(move)
	local now = os.clock()
	if now < lockedUntil or now < nextReady[move] then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local duration = moves[move].cooldown
	lockedUntil = now + duration
	nextReady[move] = now + duration
	remote:FireServer(move)
end

for move, button in pairs(buttons) do
	button.Activated:Connect(function() useMove(move) end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	for move, cfg in pairs(moves) do
		if input.KeyCode == cfg.key then
			useMove(move)
			break
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		for move, button in pairs(buttons) do
			local remaining = math.max(0, nextReady[move] - os.clock())
			button.Text = "[" .. moves[move].key.Name .. "]   " .. moves[move].label
				.. (remaining > 0 and string.format("  %.1fs", remaining) or "")
			button.BackgroundColor3 = remaining > 0 and Color3.fromRGB(48, 49, 58) or Color3.fromRGB(37, 44, 63)
		end
		task.wait(0.08)
	end
end)
