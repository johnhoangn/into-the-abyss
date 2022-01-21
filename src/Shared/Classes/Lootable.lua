local DeepObject = require(script.Parent.DeepObject)
local Lootable = {}
Lootable.__index = Lootable
setmetatable(Lootable, DeepObject)


function Lootable.new(dropID, itemData)
	local self = setmetatable(DeepObject.new({
        DropID = dropID;
        Item = itemData;
    }), Lootable)
	
    self:AddSignal("Looted")
    self:AddSignal("Decayed")
    self:AddSignal("Unlocked")

	return self
end


function Lootable.fromData(lootableData)
    local lootItem = Lootable.new(lootableData.DropID, lootableData.Item)
    for k, v in pairs(lootableData) do
        lootItem[k] = v
    end
    return lootItem
end


function Lootable:Drop(decay, origin, endPosition)
    self.Dropped = tick()
    self.Expires = self.Dropped + decay;
    self.Origin = origin;
    self.Position = endPosition;
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


function Lootable:Encode()
    return {
        Dropped = self.Dropped;
        Expires = self.Expires;
        Origin = self.Origin;
        Position = self.Position;
        DropID = self.DropID;
        Item = self.Item;
    }
end


return Lootable
