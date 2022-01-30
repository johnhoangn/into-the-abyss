-- DamageService server
-- Responsible for calculating damage, applying damage, and informing clients of said damage(s)
--
-- Dynamese (Enduo)
-- 01.22.2022



local DamageService = { Priority = 650; }
local Network


-- Bundles attack values to be used in calculation
-- @param attacker <Entity>
-- @param meleeRate <number> % of melee to use
-- @param rangedrate <number> % of ranged to use
-- @param arcaneRate <number> % of arcane to use
-- @param allRate <number> % of all to use
function DamageService:Package(attacker, meleeRate, rangedRate, arcaneRate, allRate)
    local offensiveValues, offensiveMultipliers = attacker:GetOffensives()
    return self.Classes.DamagePackage.new(
        offensiveValues,
        offensiveMultipliers,
        meleeRate,
        rangedRate,
        arcaneRate,
        allRate
    )
end


-- Hurts the victim entity.
-- TODO: If damage is to be redirected, invoke recursively with redirected == true
--  and use the defensive values of the final receiver.
-- Even though one package is used per attack, Critical DamageService is rolled independently per victim
-- @param victim <Entity>
-- @param attacker <Entity>
-- @param package <DamagePackage>
function DamageService:Hurt(victim, attacker, package, redirected)
    local critRate = attacker:GetCriticalRate()
    local isCrit = attacker.Randoms.Critical:NextNumber() <= critRate
    local mitigated = package:Mitigate(victim, isCrit, attacker:GetCriticalMultiplier())

    victim:Hurt(mitigated.Sum, attacker.Base.Name)
    Network:FireAllClients(
        Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.EntityHurt,
            victim.Base,
            mitigated,
            attacker.Base.Name
        )
    )

    return mitigated
end


function DamageService:EngineInit()
	Network = self.Services.Network
end


function DamageService:EngineStart()
end


return DamageService