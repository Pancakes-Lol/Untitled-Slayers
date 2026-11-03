-- Disable old Studio-authored currency LocalScripts before StarterGui is cloned to players.
-- Coins/Gems now live under player.Currency, not leaderstats.
local StarterGui = game:GetService("StarterGui")

local function isLegacyCurrencyScript(obj)
	if not obj:IsA("LocalScript") then return false end
	if obj.Name == "CoinsLabel" or obj.Name == "GemsLabel" then return true end

	local parent = obj.Parent
	while parent and parent ~= StarterGui do
		if parent.Name == "CashLabel" or parent.Name == "GemLabel" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function disableIfLegacy(obj)
	if isLegacyCurrencyScript(obj) then
		obj.Disabled = true
	end
end

for _, obj in ipairs(StarterGui:GetDescendants()) do
	disableIfLegacy(obj)
end

StarterGui.DescendantAdded:Connect(disableIfLegacy)
