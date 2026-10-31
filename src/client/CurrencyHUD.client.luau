-- Bridges the existing MainUI currency display to the hidden Currency folder.
-- Coins/Gems stay out of leaderstats while the original bottom-left GUI keeps working.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local currency = player:WaitForChild("Currency")
local coins = currency:WaitForChild("Coins")
local gems = currency:WaitForChild("Gems")

local mainUI = playerGui:WaitForChild("MainUI")
local mainFrame = mainUI:WaitForChild("MainFrame")
local cashContainer = mainFrame:WaitForChild("CashLabel")
local gemContainer = mainFrame:WaitForChild("GemLabel")

local function disableOldScript(container, scriptName)
	local old = container:FindFirstChild(scriptName)
	if old and old:IsA("LocalScript") then
		old.Disabled = true
	end
end

disableOldScript(cashContainer, "CoinsLabel")
disableOldScript(gemContainer, "GemsLabel")

local function findDisplayLabel(container)
	if container:IsA("TextLabel") or container:IsA("TextButton") then
		return container
	end
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if obj.Name ~= "CurrencyCaption" then
				return obj
			end
		end
	end
	return nil
end

local function addCaption(container, text)
	local existing = container:FindFirstChild("CurrencyCaption")
	if existing and existing:IsA("TextLabel") then
		existing.Text = text
		return existing
	end

	local caption = Instance.new("TextLabel")
	caption.Name = "CurrencyCaption"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, 1)
	caption.Size = UDim2.new(1, 0, 0, 12)
	caption.Font = Enum.Font.GothamMedium
	caption.Text = text
	caption.TextSize = 8
	caption.TextColor3 = Color3.fromRGB(190, 194, 207)
	caption.TextTransparency = 0.1
	caption.TextStrokeTransparency = 0.8
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.ZIndex = math.max(container.ZIndex + 1, 2)
	caption.Parent = container
	return caption
end

local cashText = findDisplayLabel(cashContainer)
local gemText = findDisplayLabel(gemContainer)

addCaption(cashContainer, "COINS")
addCaption(gemContainer, "GEMS")

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
