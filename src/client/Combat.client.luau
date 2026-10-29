-- Untitled Slayers: F = Punch, G = Roundhouse Kick.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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


-- Animate Motor6D C0 locally so the move is immediately visible.
-- Supports both R6 and R15 rigs without published animation IDs.
local animationSerial = 0
local function animateMove(move)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local joints = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			joints[descendant.Name] = descendant
		end
	end
	local arm = joints.RightShoulder or joints["Right Shoulder"]
	local leg = joints.RightHip or joints["Right Hip"]
	local torso = joints.Waist or joints.RootJoint or joints.Root
	if not arm and not leg then
		warn("[Untitled Slayers] No character joints found for combat animation")
		return
	end
	animationSerial += 1
	local serial = animationSerial
	local original = {}
	for _, joint in {arm, leg, torso} do
		if joint then original[joint] = joint.C0 end
	end
	local function pose(duration, offsets)
		for joint, rotation in pairs(offsets) do
			if joint.Parent then
				TweenService:Create(joint, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					C0 = original[joint] * rotation
				}):Play()
			end
		end
	end
	local windup = {}
	if arm then windup[arm] = CFrame.Angles(math.rad(25), 0, math.rad(-35)) end
	if torso then windup[torso] = CFrame.Angles(0, math.rad(-25), 0) end
	if move == "Kick" and leg then windup[leg] = CFrame.Angles(math.rad(35), 0, math.rad(25)) end
	pose(move == "Punch" and 0.10 or 0.19, windup)
	task.wait(move == "Punch" and 0.10 or 0.19)
	if serial ~= animationSerial or player.Character ~= character then return end
	local attack = {}
	if arm then attack[arm] = move == "Punch" and CFrame.Angles(math.rad(-105), 0, math.rad(10)) or CFrame.Angles(math.rad(-20), 0, math.rad(30)) end
	if torso then attack[torso] = CFrame.Angles(0, math.rad(move == "Punch" and 35 or 65), 0) end
	if move == "Kick" and leg then attack[leg] = CFrame.Angles(math.rad(-100), math.rad(20), math.rad(-30)) end
	pose(move == "Punch" and 0.12 or 0.22, attack)
	task.wait(move == "Punch" and 0.12 or 0.22)
	if serial ~= animationSerial or player.Character ~= character then return end
	for joint, base in pairs(original) do
		if joint.Parent then
			TweenService:Create(joint, TweenInfo.new(move == "Punch" and 0.20 or 0.40, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {C0 = base}):Play()
		end
	end
end

local function useMove(move)
	local now = os.clock()
	if now < lockedUntil or now < nextReady[move] then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local duration = moves[move].cooldown
	lockedUntil = now + duration
	nextReady[move] = now + duration
	task.spawn(animateMove, move)
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
