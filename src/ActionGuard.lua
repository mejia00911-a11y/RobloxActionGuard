--!strict

local Players = game:GetService("Players")

export type RateLimitConfig = {
	MaxCalls: number,
	Window: number,
}

export type Validator = (player: Player) -> (boolean, string?)

export type Config = {
	Cooldown: number?,
	RequireAlive: boolean?,
	RateLimit: RateLimitConfig?,
	Validators: { Validator }?,
}

type PlayerState = {
	LastAllowedAt: number?,
	CallTimes: { number },
}

local ActionGuard = {}
ActionGuard.__index = ActionGuard

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function ActionGuard.new(config: Config?)
	local self = setmetatable({}, ActionGuard)

	self._config = config or {}
	self._states = {} :: { [Player]: PlayerState }
	self._destroyed = false

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
	end)

	return self
end

function ActionGuard:_getState(player: Player): PlayerState
	local state = self._states[player]

	if not state then
		state = {
			LastAllowedAt = nil,
			CallTimes = {},
		}

		self._states[player] = state
	end

	return state
end

function ActionGuard:_passesRateLimit(state: PlayerState, now: number): (boolean, string?)
	local rateLimit = self._config.RateLimit
	if not rateLimit then
		return true
	end

	local maxCalls = math.max(1, rateLimit.MaxCalls)
	local window = math.max(0.05, rateLimit.Window)

	local cutoff = now - window
	local callTimes = state.CallTimes

	local writeIndex = 1
	for readIndex = 1, #callTimes do
		local timestamp = callTimes[readIndex]

		if timestamp > cutoff then
			callTimes[writeIndex] = timestamp
			writeIndex += 1
		end
	end

	for index = writeIndex, #callTimes do
		callTimes[index] = nil
	end

	if #callTimes >= maxCalls then
		return false, "Rate limit exceeded"
	end

	table.insert(callTimes, now)

	return true
end

function ActionGuard:Validate(player: Player): (boolean, string?)
	if self._destroyed then
		return false, "Guard destroyed"
	end

	if player.Parent ~= Players then
		return false, "Invalid player"
	end

	if self._config.RequireAlive and not isAlive(player) then
		return false, "Player is not alive"
	end

	local now = os.clock()
	local state = self:_getState(player)

	local passedRateLimit, rateLimitReason = self:_passesRateLimit(state, now)
	if not passedRateLimit then
		return false, rateLimitReason
	end

	local cooldown = self._config.Cooldown
	if cooldown and cooldown > 0 then
		local lastAllowedAt = state.LastAllowedAt

		if lastAllowedAt and (now - lastAllowedAt) < cooldown then
			return false, "Cooldown active"
		end
	end

	local validators = self._config.Validators
	if validators then
		for _, validator in validators do
			local ok, allowed, reason = pcall(validator, player)

			if not ok then
				warn("[ActionGuard] Validator error:", allowed)
				return false, "Validator error"
			end

			if not allowed then
				return false, reason or "Rejected by validator"
			end
		end
	end

	state.LastAllowedAt = now
	return true
end

function ActionGuard:Reset(player: Player)
	self._states[player] = nil
end

function ActionGuard:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._states = {}

	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
		self._playerRemovingConnection = nil
	end
end

function ActionGuard.WithinDistance(player: Player, target: Instance, maxDistance: number): boolean
	if maxDistance < 0 then
		return false
	end

	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	local targetPosition: Vector3?

	if target:IsA("BasePart") then
		targetPosition = target.Position
	elseif target:IsA("Model") then
		targetPosition = target:GetPivot().Position
	else
		return false
	end

	return (root.Position - targetPosition).Magnitude <= maxDistance
end

return ActionGuard
