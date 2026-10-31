-- Fallback copy of the enemy config for Rojo hot-reload safety.
-- Primary location remains ReplicatedStorage.Assets.Configs.EnemyConfig.
return {
	AshenPup = {
		ModelName = "AshenPup",
		SpawnFolder = "AshenPup",
		RespawnTime = 5,
		Health = 60,
		AttackDamage = 7,
		AttackRange = 4.5,
		AttackCooldown = 1.2,
		AggroRange = 16,
		LeashDistance = 10,
		WalkSpeed = 10,
		XPReward = {Min = 1, Max = 10},
		PossibleRewards = {Coins = {Min = 5, Max = 5}},
	},
	WolfScout = {
		ModelName = "WolfScout",
		SpawnFolder = "WolfScout",
		RespawnTime = 7,
		Health = 110,
		AttackDamage = 12,
		AttackRange = 4.75,
		AttackCooldown = 1.05,
		AggroRange = 18,
		LeashDistance = 10,
		WalkSpeed = 12,
		XPReward = {Min = 10, Max = 20},
		PossibleRewards = {Coins = {Min = 15, Max = 15}},
	},
}
