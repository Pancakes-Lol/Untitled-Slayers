-- Tetsu dialogue: interactive choices, keyboard shortcuts and mobile buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TetsuDialogue")

local gui = Instance.new("ScreenGui")
gui.Name = "TetsuDialogueUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "DialoguePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -32)
panel.Size = UDim2.new(0.88, 0, 0, 286)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(570, 286)
sizeLimit.Parent = panel
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local outline = Instance.new("UIStroke", panel)
outline.Color = Color3.fromRGB(130, 112, 235)
outline.Thickness = 2

local function label(name, text, y, height, font, size, color)
	local obj = Instance.new("TextLabel")
	obj.Name = name
	obj.BackgroundTransparency = 1
	obj.Position = UDim2.new(0, 18, 0, y)
	obj.Size = UDim2.new(1, -36, 0, height)
	obj.Text = text
	obj.TextColor3 = color
	obj.TextSize = size
	obj.Font = font
	obj.TextWrapped = true
	obj.TextXAlignment = Enum.TextXAlignment.Left
	obj.TextYAlignment = Enum.TextYAlignment.Center
	obj.Parent = panel
	return obj
end
label("Name", "TETSU  •  THE WANDERING WARRIOR", 9, 26, Enum.Font.GothamBold, 15, Color3.fromRGB(193, 180, 255))
local question = label("Question", "", 40, 52, Enum.Font.GothamSemibold, 17, Color3.fromRGB(255, 255, 255))

local buttons = {}
for i = 1, 3 do
	local button = Instance.new("TextButton")
	button.Name = "Choice" .. i
	button.Position = UDim2.new(0, 18, 0, 96 + (i-1)*45)
	button.Size = UDim2.new(1, -36, 0, 39)
	button.BackgroundColor3 = Color3.fromRGB(42, 49, 72)
	button.TextColor3 = Color3.fromRGB(247, 247, 255)
	button.TextSize = 14
	button.Font = Enum.Font.GothamMedium
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextWrapped = true
	button.Parent = panel
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	buttons[i] = button
end
local nextButton = Instance.new("TextButton")
nextButton.Name = "Next"
nextButton.Position = UDim2.new(0, 18, 0, 118)
nextButton.Size = UDim2.new(1, -36, 0, 47)
nextButton.BackgroundColor3 = Color3.fromRGB(91, 73, 180)
nextButton.TextColor3 = Color3.new(1, 1, 1)
nextButton.Font = Enum.Font.GothamBold
nextButton.TextSize = 15
nextButton.Text = "Another question  →"
nextButton.Visible = false
nextButton.Parent = panel
Instance.new("UICorner", nextButton).CornerRadius = UDim.new(0, 8)

local close = Instance.new("TextButton")
close.Name = "Close"
close.Position = UDim2.new(1, -50, 0, 7)
close.Size = UDim2.fromOffset(34, 30)
close.BackgroundTransparency = 1
close.TextColor3 = Color3.fromRGB(200, 200, 215)
close.Text = "✕"
close.Font = Enum.Font.GothamBold
close.TextSize = 20
close.Parent = panel

local phase = "Closed"
local function dismiss()
	panel.Visible = false
	phase = "Closed"
	remote:FireServer("Close")
end
close.Activated:Connect(dismiss)
for i, button in ipairs(buttons) do
	button.Activated:Connect(function()
		if phase ~= "Question" then return end
		phase = "Waiting"
		remote:FireServer("Answer", i)
	end)
end
nextButton.Activated:Connect(function()
	if phase == "Response" then
		phase = "Waiting"
		remote:FireServer("Next")
	end
end)
remote.OnClientEvent:Connect(function(action, data)
	if action == "Close" then
		panel.Visible = false
		phase = "Closed"
	elseif action == "Question" then
		panel.Visible = true
		phase = "Question"
		question.Text = data.question
		for i, button in ipairs(buttons) do
			button.Visible = true
			button.Text = tostring(i) .. ".  " .. tostring(data.answers[i])
		end
		nextButton.Visible = false
	elseif action == "Response" then
		panel.Visible = true
		phase = "Response"
		question.Text = data.text
		for _, button in ipairs(buttons) do button.Visible = false end
		nextButton.Visible = true
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or phase ~= "Question" or UserInputService:GetFocusedTextBox() then return end
	local number = ({[Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2, [Enum.KeyCode.Three]=3})[input.KeyCode]
	if number then buttons[number]:Activate() end
end)
