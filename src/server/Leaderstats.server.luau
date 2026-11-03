-- Persistent player progression/currency bootstrap.
-- PlayerData owns loading, autosaving, leave saves, and shutdown saves.
local Players = game:GetService("Players")
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local function setup(player)
	PlayerData.LoadPlayer(player)
end

Players.PlayerAdded:Connect(setup)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setup, player)
end
