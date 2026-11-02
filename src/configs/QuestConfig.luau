-- Central quest definitions for Untitled Slayers.
-- Rojo maps this module to ReplicatedStorage.Assets.Configs.QuestConfig.
local QuestConfig = {
	AshenPup = {
		Title = "AshenPup Hunt",
		Enemy = "AshenPup",
		Rewards = {
			XP = 75,
			Materials = {},
			Cash = 100,
		},
		AmountOfEnemy = 6,
		QuestDescription = "Defeat 6 AshenPups to finish this quest.",
		QuestDescriptiom = "Defeat 6 AshenPups to finish this quest.", -- compatibility with the requested field spelling
		LevelRequired = 1,
	},

	WolfScout = {
		Title = "Wolf Hunt",
		Enemy = "WolfScout",
		Rewards = {
			XP = 100,
			Materials = {},
			Cash = 150,
		},
		AmountOfEnemy = 6,
		QuestDescription = "Defeat 6 WolfScouts to finish this quest.",
		QuestDescriptiom = "Defeat 6 WolfScouts to finish this quest.", -- compatibility with the requested field spelling
		LevelRequired = 1,
	},
}

return QuestConfig
