--[[
    combat_core/server/rewards.lua – kills verwerken, beloningen (met caps), killfeed, teamrondes.

    Anti-misbruik:
      * dagcap per speler (combat_stats) + globaal uurbudget voor de hele server
      * zelfde killer→slachtoffer-paar binnen pairCooldownSeconds: geen beloning én geen stat
      * slachtoffer moet minAliveSeconds geleefd hebben
      * teamkills, beschermde slachtoffers en afwijkende claims komen hier niet eens aan (rules.lua)
]]

local R = CombatCfg.Rewards

local hourBudget = { hour = 0, used = 0 }
local pairLast = {}   -- ["killerIdent>victimIdent"] = ms
local hashToLabel = {}

local function u32(h) return (tonumber(h) or 0) & 0xFFFFFFFF end

for name, label in pairs(CombatCfg.WeaponLabels) do
    hashToLabel[u32(joaat(name))] = label
end

function Combat.weaponLabel(hash)
    return hashToLabel[u32(hash)] or ServerCfg.T('combat.weapon_unknown')
end

local function budgetRemaining()
    local hour = math.floor(os.time() / 3600)
    if hourBudget.hour ~= hour then
        hourBudget.hour = hour
        hourBudget.used = 0
    end
    return math.max(0, R.globalHourlyBudget - hourBudget.used)
end

function Combat.budgetUsed()
    budgetRemaining()
    return hourBudget.used
end

local function prunePairs(now)
    local count = 0
    for _ in pairs(pairLast) do count = count + 1 end
    if count < 500 then return end
    for key, t in pairs(pairLast) do
        if now - t > R.pairCooldownSeconds * 1000 then pairLast[key] = nil end
    end
end

---------------------------------------------------------------------------
-- Geld uitkeren binnen de caps
---------------------------------------------------------------------------
--- @return number granted, boolean capped
function Combat.grantMoney(src, xPlayer, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 0, false end

    local okE, earned = pcall(function() return exports.combat_stats:GetEarnedToday(src) end)
    earned = okE and earned or R.dailyMoneyCap -- bij twijfel: niets uitkeren
    local dailyLeft = math.max(0, R.dailyMoneyCap - earned)
    local granted = math.min(amount, dailyLeft, budgetRemaining())
    local capped = granted < amount
    if granted <= 0 then return 0, capped end

    local account = R.killMoneyAccount
    if account == 'money' then
        xPlayer.addMoney(granted, reason)
    else
        xPlayer.addAccountMoney(account, granted, reason)
    end
    pcall(function() exports.combat_stats:AddEarnedToday(src, granted) end)
    hourBudget.used = hourBudget.used + granted

    exports.server_logs:Log('money', 'Combatbeloning', ('%s ontving €%d (%s) – %s. Vandaag totaal: €%d/%d'):format(
        exports.server_logs:Describe(src), granted, account, reason, earned + granted, R.dailyMoneyCap))
    if granted >= R.logRewardAtLeast then
        exports.server_logs:Log('combat', 'Grote combatbeloning', ('%s ontving €%d – %s'):format(
            exports.server_logs:Describe(src), granted, reason))
    end
    return granted, capped
end

---------------------------------------------------------------------------
-- Killfeed
---------------------------------------------------------------------------
function Combat.killfeed(zone, killerSrc, victimSrc, weaponHash, streak)
    local k = killerSrc and Combat.Players[killerSrc]
    local v = Combat.Players[victimSrc]
    local function teamColor(p)
        if p and p.team and zone.teams then
            return zone.teams[Combat.teamIndex(zone, p.team)].color
        end
        return nil
    end
    local payload = {
        killer = k and k.name or nil,
        victim = v and v.name or ('#' .. tostring(victimSrc)),
        weapon = Combat.weaponLabel(weaponHash),
        streak = streak or 0,
        zone = zone.label,
        killerColor = teamColor(k),
        victimColor = teamColor(v),
        suicide = (killerSrc == nil),
    }
    if CombatCfg.Rules.killfeedScope == 'all' then
        TriggerClientEvent('combat:killfeed', -1, payload)
    else
        for _, src in ipairs(Combat.zoneMembers(zone.id)) do
            TriggerClientEvent('combat:killfeed', src, payload)
        end
    end
end

---------------------------------------------------------------------------
-- Teamronde
---------------------------------------------------------------------------
function Combat.endRound(zone, winnerTeam)
    local members = Combat.zoneMembers(zone.id)
    local perTeam = {}
    for _, src in ipairs(members) do
        local p = Combat.Players[src]
        perTeam[p.team] = (perTeam[p.team] or 0) + 1
    end
    local teamsPresent = 0
    for _ in pairs(perTeam) do teamsPresent = teamsPresent + 1 end
    local rewarded = R.enabled and zone.rewards and teamsPresent >= 2 and #members >= R.teamWinMinPlayers

    local winnerLabel = zone.teams[Combat.teamIndex(zone, winnerTeam)].label
    for _, src in ipairs(members) do
        local p = Combat.Players[src]
        if p.team == winnerTeam then
            local text = 'combat.round_won'
            if rewarded then
                local xPlayer = ESX.GetPlayerFromId(src)
                if xPlayer then
                    local mult = (zone.rewardMultiplier or 1.0) * (Combat.jobRule(xPlayer).rewardMultiplier or 1.0)
                    local granted = Combat.grantMoney(src, xPlayer, R.teamWinBonus * mult, 'Team gewonnen in ' .. zone.label)
                    pcall(function() exports.combat_stats:AddXp(src, math.floor(R.teamWinXp * mult)) end)
                    if granted > 0 then
                        ServerCfg.Notify(src, 'success', 'combat.round_bonus', winnerLabel, granted)
                        text = nil
                    end
                end
            end
            if text then ServerCfg.Notify(src, 'success', text, winnerLabel) end
        else
            ServerCfg.Notify(src, 'inform', 'combat.round_lost', winnerLabel)
        end
    end
    Combat.Scores[zone.id] = {}
    exports.server_logs:Log('combat', 'Ronde afgelopen', ('%s: team %s wint (%d spelers)'):format(zone.label, winnerLabel, #members))
end

---------------------------------------------------------------------------
-- Kill verwerken (alleen aanroepen na validatie in rules.lua)
---------------------------------------------------------------------------
function Combat.processKill(killerSrc, victimSrc, zone, weaponHash)
    local k, v = Combat.Players[killerSrc], Combat.Players[victimSrc]
    if not k or not v then return end
    local now = Combat.now()

    k.kills = k.kills + 1
    k.streak = k.streak + 1
    local streak = k.streak

    local scores = Combat.Scores[zone.id]
    if zone.mode == 'team' then
        scores[k.team] = (scores[k.team] or 0) + 1
    end

    -- Anti-farm
    prunePairs(now)
    local pairKey = k.identifier .. '>' .. v.identifier
    local last = pairLast[pairKey]
    local pairLimited = last ~= nil and (now - last) < R.pairCooldownSeconds * 1000
    local aliveLong = (now - v.spawnedAt) >= R.minAliveSeconds * 1000
    local eligible = zone.countStats and not pairLimited and aliveLong
    if eligible then pairLast[pairKey] = now end

    local money, xp, capped = 0, 0, false
    if eligible then
        local xPlayer = ESX.GetPlayerFromId(killerSrc)
        if R.enabled and zone.rewards and xPlayer then
            local mult = (zone.rewardMultiplier or 1.0) * (Combat.jobRule(xPlayer).rewardMultiplier or 1.0)
            xp = math.floor((R.killXp + math.min((streak - 1) * R.streakXpPerKill, R.streakXpMax)) * mult)
            local rawMoney = math.floor((R.killMoney + math.min((streak - 1) * R.streakMoneyPerKill, R.streakMoneyMax)) * mult)
            money, capped = Combat.grantMoney(killerSrc, xPlayer, rawMoney,
                ('Kill op %s in %s'):format(v.name or '?', zone.label))
        end
        pcall(function() exports.combat_stats:RecordKill(killerSrc, xp, streak) end)
        MySQL.insert('INSERT INTO combat_kill_log (killer, victim, zone, weapon, money, xp) VALUES (?, ?, ?, ?, ?, ?)',
            { k.identifier, v.identifier, zone.id, Combat.weaponLabel(weaponHash), money, xp })
    end
    if zone.countStats then
        pcall(function() exports.combat_stats:RecordDeath(victimSrc) end)
    end

    if R.logAllKills then
        exports.server_logs:Log('combat', 'Kill', ('%s doodde %s met %s in %s (€%d, %d XP%s)'):format(
            exports.server_logs:Describe(killerSrc), exports.server_logs:Describe(victimSrc),
            Combat.weaponLabel(weaponHash), zone.label, money, xp, eligible and '' or ', geen beloning'))
    end

    -- Meldingen
    if eligible and (money > 0 or xp > 0) then
        ServerCfg.Notify(killerSrc, 'success', 'combat.kill_reward', v.name or '?', money, xp)
    elseif eligible and capped then
        ServerCfg.Notify(killerSrc, 'inform', 'combat.reward_capped')
    elseif not eligible then
        ServerCfg.Notify(killerSrc, 'inform', 'combat.kill_no_reward')
    end

    Combat.killfeed(zone, killerSrc, victimSrc, weaponHash, streak)
    TriggerEvent('combat:kill', {
        zone = zone.id, killer = killerSrc, victim = victimSrc,
        killerTeam = k.team, victimTeam = v.team, credited = eligible,
        victimAliveMs = now - v.spawnedAt,
    })

    if zone.mode == 'team' and (scores[k.team] or 0) >= zone.scoreLimit then
        Combat.endRound(zone, k.team)
    end
end

-- Opschonen kill-log
CreateThread(function()
    Wait(15000)
    pcall(function()
        MySQL.update('DELETE FROM combat_kill_log WHERE created_at < (NOW() - INTERVAL ? DAY)', { R.killLogDays })
    end)
end)
