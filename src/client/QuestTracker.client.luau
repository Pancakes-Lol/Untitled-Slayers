-- Quest tracking UI using the Studio-authored MainUI QuestTrackerFrame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("QuestUpdate")

local mainUI = playerGui:WaitForChild("MainUI")
mainUI.ResetOnSpawn = false

local dialogGui = playerGui:FindFirstChild("DialogUI") or playerGui:WaitForChild("DialogUI", 10)
if dialogGui then
	dialogGui.ResetOnSpawn = false
end

local mainFrame = mainUI:WaitForChild("MainFrame")
local questFrame = mainFrame:WaitForChild("QuestTrackerFrame")
local questTitleLabel = questFrame:WaitForChild("QuestTitleLabel")
local questDescriptionLabel = questFrame:WaitForChild("QuestDescriptionLabel")
local trackingLabel = questFrame:WaitForChild("TrackingLabel")
local cashLabel = questFrame:WaitForChild("CashLabel")
local expLabel = questFrame:WaitForChild("EXPLabel")
local progressBar = questFrame:FindFirstChild("ProgressBar")
local progressFill = progressBar and progressBar:FindFirstChild("ProgressBarFrame")

local latestData = {Visible = false}
questFrame.Visible = false

local function setProgress(progress, amount)
	progress = tonumber(progress) or 0
	amount = tonumber(amount) or 0
	local ratio = amount > 0 and math.clamp(progress / amount, 0, 1) or 0

	trackingLabel.Text = amount > 0 and string.format("%d / %d", math.clamp(progress, 0, amount), amount) or "0 / 0"

	if progressBar and progressBar:IsA("GuiObject") then
		progressBar.Visible = true
	end
	if progressFill and progressFill:IsA("GuiObject") then
		progressFill.Visible = true
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function render(data)
	data = data or {}
	latestData = data

	if data.Visible ~= true then
		questFrame.Visible = false
		return
	end

	if dialogGui and dialogGui.Enabled then
		questFrame.Visible = false
		return
	end

	questTitleLabel.Text = tostring(data.Title or "Quest")
	questDescriptionLabel.Text = tostring(data.Description or "")

	local rewards = type(data.Rewards) == "table" and data.Rewards or {}
	cashLabel.Text = tostring(tonumber(rewards.Cash) or 0)
	expLabel.Text = tostring(tonumber(rewards.XP) or 0)

	if data.Complete then
		trackingLabel.Text = "Complete - Return to Tetsu"
		if progressBar and progressBar:IsA("GuiObject") then progressBar.Visible = true end
		if progressFill and progressFill:IsA("GuiObject") then
			progressFill.Visible = true
			progressFill.Size = UDim2.new(1, 0, 1, 0)
		end
	else
		setProgress(data.Progress, data.Amount)
	end

	mainUI.Enabled = true
	mainFrame.Visible = true
	questFrame.Visible = true
end

remote.OnClientEvent:Connect(render)

if dialogGui then
	dialogGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if dialogGui.Enabled then
			questFrame.Visible = false
		else
			render(latestData)
		end
	end)
end

player.CharacterAdded:Connect(function()
	task.defer(function()
		if mainUI.Parent ~= playerGui then return end
		render(latestData)
	end)
end)
