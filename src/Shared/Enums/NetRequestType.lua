-- BUILT-IN ENUMS MOVE NEGATIVE

return {
	RandomOverwrite = -14;
    RandomRequest = -13;

	DataChange = -12;
	DataStream = -11;

	EffectChange = -10;
	EffectStop = -9;
	Effect = -8;

	SoundChange = -7;
	SoundStop = -6;
	Sound = -5;

	AssetRequest = -4;
	Quick = -3;
	Ready = -2;
	Test = -1;
	BulkRequest = 0;

	EntityStream = 1;
    EntityRequest = 2;
	EntityEquipmentChanged = 3;

	AnimationPackQuery = 4;
	CoreAnimatorQuery = 5;

	InventoryAction = 6;
    -- LootableDrop is an inventory action as "Drop"
    LootableTake = 7;
    LootableDropped = 8;
    LootableRemoved = 9;
    LootableUpdated = 10;
    LootableUnlocked = 11;
}