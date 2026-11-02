-- Bridges the existing MainUI currency display to the hidden Currency folder.
-- Rebinds to the current MainUI after respawn so Studio placeholder values never return.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local currency = player:WaitForChild("Currency")
local coins = currency:WaitForChild("Coins")
local gems = currency:WaitForChild("Gems")

local mainUI
local mainFrame
local cashContainer
local gemContainer
local cashText
local gemText
local dialogUI

local function disableLegacyCurrencyScript(obj)
	if obj:IsA("LocalScript") and (obj.Name == "CoinsLabel" or obj.Name == "GemsLabel") then
		obj.Disabled = true
	end
end

for _, obj in ipairs(playerGui:GetDescendants()) do
	disableLegacyCurrencyScript(obj)
end
playerGui.DescendantAdded:Connect(disableLegacyCurrencyScript)

local function findDisplayLabel(container)
	if not container then return nil end
	if container:IsA("TextLabel") or container:IsA("TextButton") then
		return container
	end
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			return obj
		end
	end
	return nil
end

local function bindCurrentGui()
	local currentMainUI = playerGui:FindFirstChild("MainUI")
	if not currentMainUI or not currentMainUI:IsA("ScreenGui") then
		return false
	end

	if mainUI ~= currentMainUI then
		mainUI = currentMainUI
		mainUI.ResetOnSpawn = false
		mainFrame = mainUI:WaitForChild("MainFrame")
		cashContainer = mainFrame:WaitForChild("CashLabel")
		gemContainer = mainFrame:WaitForChild("GemLabel")

		for _, obj in ipairs(cashContainer:GetDescendants()) do
			disableLegacyCurrencyScript(obj)
		end
		for _, obj in ipairs(gemContainer:GetDescendants()) do
			disableLegacyCurrencyScript(obj)
		end

		for _, container in ipairs({cashContainer, gemContainer}) do
			local caption = container:FindFirstChild("CurrencyCaption")
			if caption then caption:Destroy() end
		end

		cashText = findDisplayLabel(cashContainer)
		gemText = findDisplayLabel(gemContainer)
	end

	local currentDialog = playerGui:FindFirstChild("DialogUI")
	if currentDialog and currentDialog:IsA("ScreenGui") then
		dialogUI = currentDialog
	end
	return true
end

local function setGuiObjectVisible(obj, visible)
	if obj and obj:IsA("GuiObject") then
		obj.Visible = visible
	end
end

local function dialogueIsOpen()
	local currentDialog = playerGui:FindFirstChild("DialogUI")
	if currentDialog and currentDialog:IsA("ScreenGui") then
		dialogUI = currentDialog
		return currentDialog.Enabled
	end
	return false
end

local function refreshVisibility()
	if not bindCurrentGui() then return end
	if dialogueIsOpen() then return end

	mainUI.Enabled = true
	setGuiObjectVisible(mainFrame, true)
	setGuiObjectVisible(cashContainer, true)
	setGuiObjectVisible(gemContainer, true)
	if cashText then cashText.Visible = true end
	if gemText then gemText.Visible = true end
end

local function refreshCoins()
	if not bindCurrentGui() then return end
	if cashText then
		cashText.Text = tostring(coins.Value)
	end
	refreshVisibility()
end

local function refreshGems()
	if not bindCurrentGui() then return end
	if gemText then
		gemText.Text = tostring(gems.Value)
	end
	refreshVisibility()
end

local function refreshAll()
	if not bindCurrentGui() then return end
	refreshCoins()
	refreshGems()
end

coins:GetPropertyChangedSignal("Value"):Connect(refreshCoins)
gems:GetPropertyChangedSignal("Value"):Connect(refreshGems)

local function hookDialog(currentDialog)
	if not currentDialog or not currentDialog:IsA("ScreenGui") then return end
	dialogUI = currentDialog
	currentDialog:GetPropertyChangedSignal("Enabled"):Connect(function()
		if currentDialog.Parent == playerGui and not currentDialog.Enabled then
			task.defer(refreshAll)
		end
	end)
end

local existingDialog = playerGui:FindFirstChild("DialogUI")
if existingDialog then
	hookDialog(existingDialog)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "MainUI" and child:IsA("ScreenGui") then
		-- Roblox can recreate MainUI after respawn. Rebind immediately and overwrite
		-- the Studio placeholder text with the player's real currency values.
		task.defer(function()
			if child.Parent == playerGui then
				mainUI = nil
				bindCurrentGui()
				refreshAll()
			end
		end)
	elseif child.Name == "DialogUI" and child:IsA("ScreenGui") then
		hookDialog(child)
	end
end)

player.CharacterAdded:Connect(function()
	-- Rebind more than once because PlayerGui replacement timing varies during respawn.
	for _, delayTime in ipairs({0.05, 0.35, 0.9, 1.5}) do
		task.delay(delayTime, function()
			local currentMainUI = playerGui:FindFirstChild("MainUI")
			if currentMainUI ~= mainUI then
				mainUI = nil
			end
			refreshAll()
		end)
	end
end)

bindCurrentGui()
refreshAll()
