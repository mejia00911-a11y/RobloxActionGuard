local ActionGuard = {}
ActionGuard.__index = ActionGuard

function ActionGuard.new(config)
	config = config or {}

	local self = setmetatable({
		_cooldown = config.Cooldown or 0,
		_requireAlive = if config.RequireAlive ~= nil then config.RequireAlive else false,
		_rateLimit = config.RateLimit,
		_lastAllowed = {},
		_callTimestamps = {},
		_validators = {},
	}, ActionGuard)

	return self
end

function ActionGuard:AddValidator(name, callback)
	self._validators[name] = callback
end

function ActionGuard:WithinDistance(player, target, maxDistance)
	if not player or not player.Parent then
		return false, "Player is not valid"
	end

	local character = player.Character
	if not character then
		return false, "Character not found"
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "HumanoidRootPart not found"
	end

	local targetPosition
	if typeof(target) == "Vector3" then
		targetPosition = target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			targetPosition = target.Position
		elseif target:IsA("Model") and target.PrimaryPart then
			targetPosition = target.PrimaryPart.Position
		else
			return false, "Invalid target instance"
		end
	else
		return false, "Invalid target type"
	end

	local distance = (hrp.Position - targetPosition).Magnitude
	if distance <= maxDistance then
		return true
	else
		return false, "Out of range"
	end
end

function ActionGuard:Validate(player)
	if not player or not player.Parent then
		return false, "Player is not valid"
	end

	if self._requireAlive then
		local character = player.Character
		if not character then
			return false, "Character not found"
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false, "Player is not alive"
		end
	end

	local now = os.clock()

	-- Rate limit check
	if self._rateLimit then
		local maxCalls = self._rateLimit.MaxCalls or math.huge
		local window = self._rateLimit.Window or 0

		if window > 0 and maxCalls < math.huge then
			local timestamps = self._callTimestamps[player] or {}

			-- Remove timestamps outside the window
			local valid = {}
			for _, ts in ipairs(timestamps) do
				if now - ts <= window then
					table.insert(valid, ts)
				end
			end

			if #valid >= maxCalls then
				self._callTimestamps[player] = valid
				return false, "Rate limit exceeded"
			end

			table.insert(valid, now)
			self._callTimestamps[player] = valid
		end
	end

	-- Cooldown check
	if self._cooldown > 0 then
		local last = self._lastAllowed[player]
		if last and (now - last) < self._cooldown then
			return false, "On cooldown"
		end
	end

	self._lastAllowed[player] = now

	-- Custom validators
	local character = player.Character
	for name, validator in pairs(self._validators) do
		local ok, reason = validator(player, character)
		if not ok then
			return false, reason or ("Validator failed: " .. name)
		end
	end

	return true
end

return ActionGuard
