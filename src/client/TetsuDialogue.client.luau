-- Tetsu dialogue controller using the Studio-authored DialogUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TetsuDialogue")
local playerGui = player:WaitForChild("PlayerGui")

local gui = playerGui:WaitForChild("DialogUI")
local mainFrame = gui:WaitForChild("MainFrame")
local dialogFrame = mainFrame:WaitForChild("DialogFrame")
local npcName = dialogFrame:WaitForChild("NPCNameTextHolder")
local message = dialogFrame:WaitForChild("NPCDialogSpeach")
local optionsFrame = dialogFrame:WaitForChild("OptionsFrame")

local optionButtons = {}
for _, child in ipairs(optionsFrame:GetChildren()) do
	if child:IsA("TextButton") and child.Name == "OptionButtonTemplate" then
		table.insert(optionButtons, child)
	end
end

if #optionButtons < 3 then
	warn("[TetsuDialogue] DialogUI needs three OptionButtonTemplate buttons.")
end

for i, button in ipairs(optionButtons) do
	button.LayoutOrder = i
	button.Visible = false
	button.TextSize = math.min(button.TextSize, 18)
end

npcName.Text = "Tetsu"
gui.Enabled = false

local phase = "Closed"
local storyAction = "Continue"

local function hideButtons()
	for _, button in ipairs(optionButtons) do
		button.Visible = false
		button.Active = false
	end
end

local function closeDialogue(notifyServer)
	hideButtons()
	gui.Enabled = false
	phase = "Closed"
	if notifyServer then
		remote:FireServer("Close")
	end
end

local function showButton(index, text, callback)
	local button = optionButtons[index]
	if not button then return end
	button.Text = text
	button.Visible = true
	button.Active = true

	local connection
	connection = button.Activated:Connect(function()
		if not button.Active then return end
		button.Active = false
		if connection then connection:Disconnect() end
		callback()
	end)
end

local buttonConnections = {}
local function disconnectButtons()
	for _, connection in ipairs(buttonConnections) do
		connection:Disconnect()
	end
	table.clear(buttonConnections)
end

local function bindButton(index, text, callback)
	local button = optionButtons[index]
	if not button then return end
	button.Text = text
	button.Visible = true
	button.Active = true
	local connection = button.Activated:Connect(function()
		if phase == "Waiting" or phase == "Closed" then return end
		disconnectButtons()
		hideButtons()
		callback()
	end)
	table.insert(buttonConnections, connection)
end

local function beginDisplay(text)
	disconnectButtons()
	hideButtons()
	npcName.Text = "Tetsu"
	message.Text = text or ""
	gui.Enabled = true
end

remote.OnClientEvent:Connect(function(action, data)
	data = data or {}

	if action == "Close" then
		disconnectButtons()
		closeDialogue(false)
		return
	end

	if action == "Question" then
		beginDisplay(data.question)
		phase = "Question"
		for i = 1, math.min(3, #optionButtons) do
			local answer = data.answers and data.answers[i]
			if answer ~= nil then
				bindButton(i, tostring(i) .. ".  " .. tostring(answer), function()
					phase = "Waiting"
					remote:FireServer("Choose", i)
				end)
			end
		end
		return
	end

	if action == "Quest" then
		beginDisplay(data.text)
		phase = "Story"
		storyAction = "Continue"
		bindButton(1, "Got it", function()
			phase = "Waiting"
			remote:FireServer("Continue")
		end)
		return
	end

	if action == "Story" then
		beginDisplay(data.text)
		phase = "Story"
		local buttonText = data.button or "Continue"
		storyAction = buttonText == "Accept sword & quest" and "Accept" or "Continue"
		bindButton(1, buttonText, function()
			phase = "Waiting"
			remote:FireServer(storyAction)
		end)
		return
	end

	-- The current Tetsu server no longer asks players to choose a custom name.
	-- Keep a safe fallback in case an older server sends one of these actions.
	if action == "NameEntry" or action == "NameError" then
		beginDisplay(action == "NameError" and data.text or "Tetsu already knows your slayer name.")
		phase = "Story"
		bindButton(1, "Continue", function()
			phase = "Waiting"
			remote:FireServer("Continue")
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		disconnectButtons()
		closeDialogue(true)
		return
	end

	if phase ~= "Question" or UserInputService:GetFocusedTextBox() then return end
	local keys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
	}
	local index = keys[input.KeyCode]
	if not index or not optionButtons[index] or not optionButtons[index].Visible then return end

	disconnectButtons()
	hideButtons()
	phase = "Waiting"
	remote:FireServer("Choose", index)
end)
