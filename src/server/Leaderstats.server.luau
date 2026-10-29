-- Temporary session-only currency values for the existing MainUI scripts.
-- Replace with your persistent currency system when it is ready.
local Players = game:GetService("Players")

local function setup(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	for _, name in {"Coins", "Gems"} do
		if not stats:FindFirstChild(name) then
			local value = Instance.new("IntValue")
			value.Name = name
			value.Value = 0
			value.Parent = stats
		end
	end
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	setup(player)
end
