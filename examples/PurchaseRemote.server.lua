--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ActionGuard = require(ServerScriptService.Packages.ActionGuard)

local PurchaseRemote = ReplicatedStorage.Remotes.PurchaseItem

local purchaseGuard = ActionGuard.new({
	Cooldown = 0.25,
	RateLimit = {
		MaxCalls = 5,
		Window = 2,
	},
})

PurchaseRemote.OnServerEvent:Connect(function(player: Player, itemId: string)
	local allowed = purchaseGuard:Validate(player)
	if not allowed then
		return
	end

	if typeof(itemId) ~= "string" then
		return
	end

	-- Validate itemId, price and player currency on the server.
end)
