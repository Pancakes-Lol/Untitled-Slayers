-- Tetsu dialogue UI: choices, custom name entry, quest notifications.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TetsuDialogue")

local gui = Instance.new("ScreenGui")
gui.Name = "TetsuDialogueUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "DialoguePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -28)
panel.Size = UDim2.new(0.9, 0, 0, 280)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(570, 280)
limit.Parent = panel
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(130, 112, 235)
stroke.Thickness = 2
stroke.Parent = panel

local function textLabel(name, value, y, height, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 18, 0, y)
	label.Size = UDim2.new(1, -36, 0, height)
	label.Font = Enum.Font.GothamSemibold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = value
	label.Parent = panel
	return label
end
textLabel("Heading", "TETSU  •  YOUR SLAYER JOURNEY", 7, 29, 14)
local message = textLabel("Message", "", 40, 62, 17)
local function button(name, y, height)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = UDim2.new(0, 18, 0, y)
	b.Size = UDim2.new(1, -36, 0, height)
	b.BackgroundColor3 = Color3.fromRGB(52, 58, 83)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 15
	b.Font = Enum.Font.GothamMedium
	b.TextWrapped = true
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end
local choices = {button("Choice1", 103, 40), button("Choice2", 148, 40), button("Choice3", 193, 40)}
local nextButton = button("Continue", 137, 46)
nextButton.Visible = false
local nameInput = Instance.new("TextBox")
nameInput.Name = "CustomName"
nameInput.Position = UDim2.new(0, 18, 0, 113)
nameInput.Size = UDim2.new(1, -36, 0, 43)
nameInput.BackgroundColor3 = Color3.fromRGB(43, 48, 68)
nameInput.TextColor3 = Color3.new(1, 1, 1)
nameInput.PlaceholderText = "Your slayer name (3–20 characters)"
nameInput.Text = ""
nameInput.ClearTextOnFocus = false
nameInput.Font = Enum.Font.GothamMedium
nameInput.TextSize = 15
nameInput.Visible = false
nameInput.Parent = panel
Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 8)
local confirm = button("ConfirmName", 166, 43)
confirm.Text = "Confirm my name"
confirm.Visible = false
local close = Instance.new("TextButton")
close.Name = "Close"
close.Position = UDim2.new(1, -50, 0, 6)
close.Size = UDim2.fromOffset(34, 30)
close.BackgroundTransparency = 1
close.TextColor3 = Color3.new(1, 1, 1)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 17
close.Parent = panel
local phase = "Closed"
local storyAction = "Continue"
local function hideControls()
	for _, b in ipairs(choices) do b.Visible = false end
	nextButton.Visible = false
	nameInput.Visible = false
	confirm.Visible = false
end
local function dismiss()
	panel.Visible = false
	phase = "Closed"
	remote:FireServer("Close")
end
close.Activated:Connect(dismiss)
local function choose(i)
	if phase ~= "Question" then return end
	phase = "Waiting"
	remote:FireServer("Choose", i)
end
for i, b in ipairs(choices) do
	b.Activated:Connect(function() choose(i) end)
end
confirm.Activated:Connect(function()
	if phase ~= "NameEntry" then return end
	phase = "Waiting"
	remote:FireServer("CustomName", nameInput.Text)
end)
nextButton.Activated:Connect(function()
	if phase ~= "Story" then return end
	phase = "Waiting"
	remote:FireServer(storyAction)
end)
remote.OnClientEvent:Connect(function(action, data)
	data = data or {}
	if action == "Close" then
		panel.Visible = false
		phase = "Closed"
		return
	end
	if action == "Quest" then
		panel.Visible = true
		hideControls()
		phase = "Story"
		storyAction = "Continue"
		message.Text = data.text
		nextButton.Text = "Got it"
		nextButton.Visible = true
		return
	end
	panel.Visible = true
	hideControls()
	if action == "Question" then
		phase = "Question"
		message.Text = data.question
		for i, b in ipairs(choices) do
			b.Text = tostring(i)..".  "..tostring(data.answers[i])
			b.Visible = true
		end
	elseif action == "NameEntry" or action == "NameError" then
		phase = "NameEntry"
		message.Text = action == "NameError" and data.text or "Choose your custom in-game slayer name."
		nameInput.Visible = true
		confirm.Visible = true
	elseif action == "Story" then
		phase = "Story"
		message.Text = data.text
		nextButton.Text = data.button or "Continue"
		storyAction = data.button == "Accept sword & quest" and "Accept" or "Continue"
		nextButton.Visible = true
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or phase ~= "Question" or UserInputService:GetFocusedTextBox() then return end
	local keys = {[Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2, [Enum.KeyCode.Three]=3}
	if keys[input.KeyCode] then choose(keys[input.KeyCode]) end
end)
