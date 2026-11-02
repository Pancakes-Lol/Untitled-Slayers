-- Tetsu dialogue controller using the Studio-authored DialogUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TetsuDialogue")
local playerGui = player:WaitForChild("PlayerGui")

local gui = playerGui:WaitForChild("DialogUI")
gui.ResetOnSpawn = false
local mainUI = playerGui:FindFirstChild("MainUI")
if mainUI and mainUI:IsA("ScreenGui") then
	mainUI.ResetOnSpawn = false
end

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
table.sort(optionButtons, function(a, b)
	return a.LayoutOrder < b.LayoutOrder
end)

if #optionButtons < 3 then
	warn("[TetsuDialogue] DialogUI needs three OptionButtonTemplate buttons.")
end

local function findButtonLabel(button)
	for _, name in ipairs({"OptionLabel", "ButtonLabel", "Label", "OptionText", "TextLabel"}) do
		local candidate = button:FindFirstChild(name, true)
		if candidate and candidate:IsA("TextLabel") then return candidate end
	end
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") then return descendant end
	end
	return nil
end

local function setButtonLabel(button, text)
	local label = findButtonLabel(button)
	if label then
		button.Text = ""
		label.Text = text
	else
		button.Text = text
	end
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
local uiLocked = false
local savedGuiStates = {}
local playerGuiChildConnection
local buttonConnections = {}

local function setBackpackEnabled(enabled)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
end

local function lockOtherUI()
	if uiLocked then return end
	uiLocked = true
	table.clear(savedGuiStates)
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= gui then
			savedGuiStates[child] = child.Enabled
			child.Enabled = false
		end
	end
	setBackpackEnabled(false)

	playerGuiChildConnection = playerGui.ChildAdded:Connect(function(child)
		if uiLocked and child:IsA("ScreenGui") and child ~= gui then
			if savedGuiStates[child] == nil then savedGuiStates[child] = child.Enabled end
			child.Enabled = false
		end
	end)
end

local function restoreOtherUI()
	if playerGuiChildConnection then
		playerGuiChildConnection:Disconnect()
		playerGuiChildConnection = nil
	end
	if uiLocked then
		uiLocked = false
		for screenGui, wasEnabled in pairs(savedGuiStates) do
			if screenGui.Parent == playerGui then screenGui.Enabled = wasEnabled end
		end
		table.clear(savedGuiStates)
	end
	setBackpackEnabled(true)
end

local function hideButtons()
	for _, button in ipairs(optionButtons) do
		button.Visible = false
		button.Active = false
	end
end

local function disconnectButtons()
	for _, connection in ipairs(buttonConnections) do connection:Disconnect() end
	table.clear(buttonConnections)
end

local function closeDialogue(notifyServer)
	disconnectButtons()
	hideButtons()
	gui.Enabled = false
	restoreOtherUI()
	phase = "Closed"
	if notifyServer then remote:FireServer("Close") end
end

local function bindButton(index, text, callback)
	local button = optionButtons[index]
	if not button then return end
	setButtonLabel(button, text)
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
	lockOtherUI()
	gui.Enabled = true
end

remote.OnClientEvent:Connect(function(action, data)
	data = data or {}
	if action == "Close" then closeDialogue(false) return end

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
		closeDialogue(true)
		return
	end
	if phase ~= "Question" or UserInputService:GetFocusedTextBox() then return end
	local keys = {[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3}
	local index = keys[input.KeyCode]
	if not index or not optionButtons[index] or not optionButtons[index].Visible then return end
	disconnectButtons()
	hideButtons()
	phase = "Waiting"
	remote:FireServer("Choose", index)
end)

player.CharacterAdded:Connect(function()
	-- Dialogue UI persists through death; always reset it to a clean closed state on respawn.
	task.defer(function()
		closeDialogue(false)
	end)
end)
