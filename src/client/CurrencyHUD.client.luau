-- Bridges the existing MainUI currency display to the hidden Currency folder.
-- Coins/Gems stay out of leaderstats while the original bottom-left GUI keeps working.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Shut down the old currency LocalScripts as early as possible so they never wait
-- for leaderstats.Coins/Gems and produce infinite-yield warnings.
local function disableLegacyCurrencyScript(obj)
	if obj:IsA("LocalScript") and (obj.Name == "CoinsLabel" or obj.Name == "GemsLabel") then
		obj.Disabled = true
	end
end

for _, obj in ipairs(playerGui:GetDescendants()) do
	disableLegacyCurrencyScript(obj)
end
playerGui.DescendantAdded:Connect(disableLegacyCurrencyScript)

local mainUI = playerGui:WaitForChild("MainUI")
local mainFrame = mainUI:WaitForChild("MainFrame")
local cashContainer = mainFrame:WaitForChild("CashLabel")
local gemContainer = mainFrame:WaitForChild("GemLabel")

-- Run one more targeted pass now that the existing MainUI is guaranteed to exist.
for _, obj in ipairs(cashContainer:GetDescendants()) do
	disableLegacyCurrencyScript(obj)
end
for _, obj in ipairs(gemContainer:GetDescendants()) do
	disableLegacyCurrencyScript(obj)
end

local currency = player:WaitForChild("Currency")
local coins = currency:WaitForChild("Coins")
local gems = currency:WaitForChild("Gems")

local function findDisplayLabel(container)
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

-- Remove any captions created by the previous version.
for _, container in ipairs({cashContainer, gemContainer}) do
	local caption = container:FindFirstChild("CurrencyCaption")
	if caption then caption:Destroy() end
end

local cashText = findDisplayLabel(cashContainer)
local gemText = findDisplayLabel(gemContainer)

local function refreshCoins()
	if cashText then cashText.Text = tostring(coins.Value) end
end

local function refreshGems()
	if gemText then gemText.Text = tostring(gems.Value) end
end

coins:GetPropertyChangedSignal("Value"):Connect(refreshCoins)
gems:GetPropertyChangedSignal("Value"):Connect(refreshGems)

refreshCoins()
refreshGems()
