local Combat = {}

function Combat.battle(unit1, unit2)
    local attacker, defender
    
    if math.random() < 0.5 then
        attacker, defender = unit1, unit2
    else
        attacker, defender = unit2, unit1
    end
    
    local damage = attacker.damage + math.random(-3, 3)
    damage = math.max(1, damage)
    
    defender:takeDamage(damage)
    
    if defender.health <= 0 then
        attacker.health = math.min(attacker.maxHealth, attacker.health + 10)
    end
end

return Combat