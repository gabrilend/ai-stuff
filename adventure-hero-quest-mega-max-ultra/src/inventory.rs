use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ItemType {
    Weapon,
    Armor,
    Consumable,
    Quest,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Item {
    pub name: String,
    pub description: String,
    pub item_type: ItemType,
    pub value: u32,
    pub attack_bonus: u32,
    pub defense_bonus: u32,
    pub health_restore: u32,
}

impl Item {
    pub fn new_weapon(name: &str, attack: u32, value: u32) -> Self {
        Item {
            name: name.to_string(),
            description: format!("A weapon that increases attack by {}", attack),
            item_type: ItemType::Weapon,
            value,
            attack_bonus: attack,
            defense_bonus: 0,
            health_restore: 0,
        }
    }

    pub fn new_armor(name: &str, defense: u32, value: u32) -> Self {
        Item {
            name: name.to_string(),
            description: format!("Armor that increases defense by {}", defense),
            item_type: ItemType::Armor,
            value,
            attack_bonus: 0,
            defense_bonus: defense,
            health_restore: 0,
        }
    }

    pub fn new_potion(name: &str, heal_amount: u32, value: u32) -> Self {
        Item {
            name: name.to_string(),
            description: format!("Restores {} health points", heal_amount),
            item_type: ItemType::Consumable,
            value,
            attack_bonus: 0,
            defense_bonus: 0,
            health_restore: heal_amount,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Inventory {
    pub items: Vec<Item>,
    pub equipped_weapon: Option<Item>,
    pub equipped_armor: Option<Item>,
    pub capacity: usize,
}

impl Inventory {
    pub fn new() -> Self {
        Inventory {
            items: Vec::new(),
            equipped_weapon: None,
            equipped_armor: None,
            capacity: 20,
        }
    }

    pub fn add_item(&mut self, item: Item) -> Result<(), String> {
        if self.items.len() >= self.capacity {
            return Err("Inventory is full!".to_string());
        }
        self.items.push(item);
        Ok(())
    }

    pub fn remove_item(&mut self, index: usize) -> Option<Item> {
        if index < self.items.len() {
            Some(self.items.remove(index))
        } else {
            None
        }
    }

    pub fn equip_weapon(&mut self, index: usize) -> Result<(), String> {
        if let Some(item) = self.items.get(index) {
            if item.item_type != ItemType::Weapon {
                return Err("That's not a weapon!".to_string());
            }
            
            let weapon = self.items.remove(index);
            if let Some(old_weapon) = self.equipped_weapon.take() {
                self.items.push(old_weapon);
            }
            self.equipped_weapon = Some(weapon);
            Ok(())
        } else {
            Err("Item not found!".to_string())
        }
    }

    pub fn equip_armor(&mut self, index: usize) -> Result<(), String> {
        if let Some(item) = self.items.get(index) {
            if item.item_type != ItemType::Armor {
                return Err("That's not armor!".to_string());
            }
            
            let armor = self.items.remove(index);
            if let Some(old_armor) = self.equipped_armor.take() {
                self.items.push(old_armor);
            }
            self.equipped_armor = Some(armor);
            Ok(())
        } else {
            Err("Item not found!".to_string())
        }
    }

    pub fn get_total_attack_bonus(&self) -> u32 {
        self.equipped_weapon.as_ref().map_or(0, |w| w.attack_bonus)
    }

    pub fn get_total_defense_bonus(&self) -> u32 {
        self.equipped_armor.as_ref().map_or(0, |a| a.defense_bonus)
    }
}