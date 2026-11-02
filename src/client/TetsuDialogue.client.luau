-- Tetsu dialogue controller using the Studio-authored DialogUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TetsuDialogue")
local playerGui = player:WaitForChild("PlayerGui")

local gui
local mainFrame
local dialogFrame
local npcName
local message
local optionsFrame
local optionButtons = {}
local buttonConnections = {}

local phase = "Closed"
local storyAction = "Continue"
local uiLocked = false
local savedGuiStates = {}
local playerGuiChildConnection
local savedEquippedTool = nil

local function disconnectButtons()
	for _, connection in ipairs(buttonConnections) do
		connection:Disconnect()
	end
	table.clear(buttonConnections)
end

local function findButtonLabel(button)
	for _, name in ipairs({"OptionLabel", "ButtonLabel", "Label", "OptionText", "TextLabel"}) do
		local candidate = button:FindFirstChild(name, true)
		if candidate and candidate:IsA("TextLabel") then
			return candidate
		end
	end
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			return descendant
		end
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

local function bindDialogGui()
	local currentGui = playerGui:FindFirstChild("DialogUI")
	if not currentGui then
		currentGui = playerGui:WaitForChild("DialogUI", 10)
	end
	if not currentGui or not currentGui:IsA("ScreenGui") then
		warn("[TetsuDialogue] Current PlayerGui.DialogUI is missing")
		return false
	end

	if gui ~= currentGui then
		disconnectButtons()
		gui = currentGui
		gui.ResetOnSpawn = false
		mainFrame = gui:WaitForChild("MainFrame")
		dialogFrame = mainFrame:WaitForChild("DialogFrame")
		npcName = dialogFrame:WaitForChild("NPCNameTextHolder")
		message = dialogFrame:WaitForChild("NPCDialogSpeach")
		optionsFrame = dialogFrame:WaitForChild("OptionsFrame")

		table.clear(optionButtons)
		for _, child in ipairs(optionsFrame:GetChildren()) do
			if child:IsA("TextButton") and child.Name == "OptionButtonTemplate" then
				table.insert(optionButtons, child)
			end
		end
		table.sort(optionButtons, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)

		for i, button in ipairs(optionButtons) do
			button.LayoutOrder = i
			button.Visible = false
			button.Active = false
			button.TextSize = math.min(button.TextSize, 18)
		end

		if #optionButtons < 3 then
			warn("[TetsuDialogue] DialogUI needs three OptionButtonTemplate buttons.")
		end

		npcName.Text = "Tetsu"
		gui.Enabled = false
	end

	local currentMainUI = playerGui:FindFirstChild("MainUI")
	if currentMainUI and currentMainUI:IsA("ScreenGui") then
		currentMainUI.ResetOnSpawn = false
	end
	return true
end

local function setBackpackEnabled(enabled)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
end

local function rememberEquippedTool()
	savedEquippedTool = nil
	local character = player.Character
	if not character then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			savedEquippedTool = child
			return
		end
	end
end

local function restoreEquippedTool()
	local tool = savedEquippedTool
	savedEquippedTool = nil
	if not tool or not tool.Parent then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or humanoid.Health <= 0 then return end
	if tool.Parent == character then return end
	if backpack and tool.Parent == backpack then
		humanoid:EquipTool(tool)
	end
end

local function lockOtherUI()
	if uiLocked then return end
	uiLocked = true
	rememberEquippedTool()
	table.clear(savedGuiStates)

	for _, child in ipairs(playerGui:GetChildren()) do
		-- Compare by name as well as reference so a newly respawned DialogUI is never
		-- mistaken for a HUD just because the old DialogUI reference was destroyed.
		if child:IsA("ScreenGui") and child.Name ~= "DialogUI" then
			savedGuiStates[child] = child.Enabled
			child.Enabled = false
		end
	end
	setBackpackEnabled(false)

	if playerGuiChildConnection then
		playerGuiChildConnection:Disconnect()
	end
	playerGuiChildConnection = playerGui.ChildAdded:Connect(function(child)
		if uiLocked and child:IsA("ScreenGui") and child.Name ~= "DialogUI" then
			if savedGuiStates[child] == nil then
				savedGuiStates[child] = child.Enabled
			end
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
			if screenGui.Parent == playerGui then
				screenGui.Enabled = wasEnabled
			end
		end
		table.clear(savedGuiStates)
	end
	setBackpackEnabled(true)
	task.delay(0.05, restoreEquippedTool)
end

local function hideButtons()
	for _, button in ipairs(optionButtons) do
		if button.Parent then
			button.Visible = false
			button.Active = false
		end
	end
end

local function closeDialogue(notifyServer)
	disconnectButtons()
	hideButtons()
	if gui and gui.Parent == playerGui then
		gui.Enabled = false
	end
	restoreOtherUI()
	phase = "Closed"
	if notifyServer then
		remote:FireServer("Close")
	end
end

local function bindButton(index, text, callback)
	local button = optionButtons[index]
	if not button or not button.Parent then return end
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
	-- Always bind to the current DialogUI before hiding any other HUD. This is the
	-- important respawn fix: never lock the live HUD while trying to open a dead GUI.
	if not bindDialogGui() then
		return false
	end
	disconnectButtons()
	hideButtons()
	npcName.Text = "Tetsu"
	message.Text = text or ""
	lockOtherUI()
	gui.Enabled = true
	return true
end

remote.OnClientEvent:Connect(function(action, data)
	data = data or {}
	if action == "Close" then
		closeDialogue(false)
		return
	end

	if action == "Question" then
		if not beginDisplay(data.question) then return end
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
		if not beginDisplay(data.text) then return end
		phase = "Story"
		storyAction = "Continue"
		bindButton(1, "Got it", function()
			phase = "Waiting"
			remote:FireServer("Continue")
		end)
		return
	end

	if action == "Story" then
		if not beginDisplay(data.text) then return end
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
		if not beginDisplay(action == "NameError" and data.text or "Tetsu already knows your slayer name.") then return end
		phase = "Story"
		bindButton(1, "Continue", function()
			phase = "Waiting"
			remote:FireServer("Continue")
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local currentGui = playerGui:FindFirstChild("DialogUI")
	if input.KeyCode == Enum.KeyCode.Escape and currentGui and currentGui:IsA("ScreenGui") and currentGui.Enabled then
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

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "DialogUI" and child:IsA("ScreenGui") then
		task.defer(function()
			if child.Parent == playerGui then
				bindDialogGui()
			end
		end)
	end
end)

player.CharacterAdded:Connect(function()
	savedEquippedTool = nil
	-- Unlock any HUD state left over from the old character first, then bind the
	-- fresh DialogUI that Roblox may have recreated for this character.
	restoreOtherUI()
	phase = "Closed"
	for _, delayTime in ipairs({0.05, 0.35, 0.9}) do
		task.delay(delayTime, function()
			if bindDialogGui() and gui and gui.Parent == playerGui then
				gui.Enabled = false
				hideButtons()
			end
		end)
	end
end)

bindDialogGui()
