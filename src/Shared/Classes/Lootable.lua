local DeepObject = require(script.Parent.DeepObject)
local Lootable = {}
Lootable.__index = Lootable
setmetatable(Lootable, DeepObject)


function Lootable.new(dropID, itemData, origin, position)
	local self = setmetatable(DeepObject.new({
        DropID = dropID;
        Item = itemData;
        Origin = origin;
        Position = position;
    }), Lootable)
	
    self:AddSignal("Looted")
    self:AddSignal("Decayed")
    self:AddSignal("Unlocked")

	return self
end


function Lootable:Drop(decay)
    self.Expires = tick() + decay;
    self.Modules.ThreadUtil.IntDelay(decay, function() self.Decayed:Fire() end, self.Looted)
    if (self.Owner ~= nil) then
        if (self.Modules.ThreadUtil.IntWait(self.UnlockOffset, self.Looted, self.Decayed) >= self.UnlockOffset) then
            self.Owner = nil
            self.Unlocked:Fire()
        end
    end
end


function Lootable:SetOwner(user, timer)
    self.Owner = user.UserId
    self.UnlockOffset = timer
end


return Lootable
