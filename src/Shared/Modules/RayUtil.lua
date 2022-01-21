-- Convenience module for various types of raycasting that are commonly used in our projects
--
-- Dynamese (Enduo)
-- 07.25.2021



local RayUtil = {}


-- Honestly kind of redundant, just to make the module complete
-- @params origin <vector3>
-- @params targetVector <vector3>
-- @params rayParams <RaycatParams>
-- @returns <RaycastResults>
function RayUtil:CastSimple(origin, targetVector, rayParams)
	return workspace:Raycast(origin, targetVector, rayParams)
end


-- Casts a ray and gathers everything along it until we encounter nil
-- Since the filter list might not be set to blacklist, instead of
--	adding the encountered instances to an ignorelist, we scoot
--	the origin forward just barely enough to cast from inside the recent
--	encounter's bounding box; therefore we won't get an inward intersection
--	with the same object twice to be detected via raycast
-- If no qualifier is given, we will retrieve *all* instances encountered
-- @param origin <Vector3>
-- @param targetVector <Vector3>
-- @param rayParams <RaycastParams>
-- @param qualifier <function> == nil
-- @returns <table<RaycastResults>>
function RayUtil:CastQualifier(origin, targetVector, rayParams, qualifier)
	local dir = targetVector.Unit/1000
	local encountered = {}
	local rayResults

	repeat
		rayResults = workspace:Raycast(origin, targetVector, rayParams)

		if (rayResults == nil) then
			break
		elseif (not qualifier or qualifier(rayResults)) then
			table.insert(encountered, rayResults)
		end

		origin = rayResults.Position + dir
	until false

	return encountered
end


return RayUtil