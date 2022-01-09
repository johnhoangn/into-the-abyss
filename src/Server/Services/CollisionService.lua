local CollisionService = { Priority = 1001 }

local PhysicsService


function CollisionService:EngineInit()
	PhysicsService = self.RBXServices.PhysicsService

    for name, _ in pairs(self.Enums.CollisionGroup) do
        if (name == "Default") then 
            continue
        end
        
        self.Enums.CollisionGroup[name] = PhysicsService:CreateCollisionGroup(name)
    end
end


function CollisionService:EngineStart()
end


return CollisionService