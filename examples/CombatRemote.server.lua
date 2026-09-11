--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ActionGuard = require(ServerScriptService.Packages.ActionGuard)

local AttackRemote = ReplicatedStorage.Remotes.Attack

local attackGuard = ActionGuard.new({
	Cooldown = 0.45,
	RequireAlive = true,
	RateLimit = {
		MaxCalls = 8,
		Window = 3,
	},
})

AttackRemote.OnServerEvent:Connect(function(player: Player, target: Instance)
	local allowed = attackGuard:Validate(player)
	if not allowed then
		return
	end

	if typeof(target) ~= "Instance" then
		return
	end

	if not ActionGuard.WithinDistance(player, target, 18) then
		return
	end

	-- Put existing server-authoritative hit validation here.
end)
