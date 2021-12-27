-- Single location to put functions that operate on player joining/leaving
-- Enduo(Dynamese)
-- 12.11.21



local PlayerService = {Priority = 500}


local Players
local JoinTasks, LeaveTasks


function PlayerService:ExecuteJoinTasks(user)
	for name, task in JoinTasks:KeyIterator() do
		-- self:Print("Executing", name, "for", user)
		if (task.Processed[user]) then continue end
		task.Processed[user] = true
		task.Callback(user)
	end
end


function PlayerService:ExecuteLeaveTasks(user)
	for _, task in LeaveTasks:KeyIterator() do
		task(user)
	end
end


function PlayerService:AddJoinTask(callback, name)
	assert(name, "nil name")
	assert(callback, "nil callback")
	JoinTasks:Add(name, {
		Callback = callback;
		Processed = {};
	})

	for _, user in ipairs(Players:GetPlayers()) do
		PlayerService:ExecuteJoinTasks(user)
	end
end


function PlayerService:AddLeaveTask(callback, name)
	assert(name, "nil name")
	assert(callback, "nil callback")
	LeaveTasks:Add(name, callback)
end


function PlayerService:EngineInit()
	JoinTasks = self.Classes.IndexedMap.new()
	LeaveTasks = self.Classes.IndexedMap.new()

	Players = self.RBXServices.Players
end


function PlayerService:EngineStart()
	Players.PlayerAdded:Connect(function(user)
		PlayerService:ExecuteJoinTasks(user)
	end)

	Players.PlayerRemoving:Connect(function(user)
		PlayerService:ExecuteLeaveTasks(user)
	end)
end


return PlayerService