-- DebugUtil (Module) - Utility for debug logging in ReplicatedStorage
local DebugUtil = {}
DebugUtil.Enabled = true  -- Set to false to disable debug logs globally

-- Log a debug message if enabled
function DebugUtil:Log(message: string)
	if DebugUtil.Enabled then
		print("[DEBUG] " .. message)
	end
end


return DebugUtil
