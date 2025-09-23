/// Relationship management for OfficeOS cryptographic communication
use crate::crypto::{CryptoError, CryptoResult, RelationshipId, RelationshipContext};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Manager for active relationships and their lifecycle
pub struct RelationshipManager {
    /// Active relationships indexed by ID
    relationships: HashMap<RelationshipId, RelationshipContext>,
    /// Configuration for relationship management
    config: RelationshipConfig,
}

/// Configuration for relationship management
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipConfig {
    /// Maximum number of active relationships
    pub max_relationships: usize,
    /// Default timeout for auto-forget relationships (seconds)
    pub default_timeout: u64,
    /// Whether to automatically clean up expired relationships
    pub auto_cleanup: bool,
    /// Minimum time between cleanup operations (seconds)
    pub cleanup_interval: u64,
}

/// Statistics about relationship usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationshipStats {
    /// Total number of active relationships
    pub total_relationships: usize,
    /// Number of relationships with auto-forget enabled
    pub auto_forget_count: usize,
    /// Number of expired relationships awaiting cleanup
    pub expired_count: usize,
    /// Average relationship age in seconds
    pub average_age: f64,
    /// Most recently contacted relationship
    pub most_recent_contact: Option<RelationshipId>,
    /// Oldest active relationship
    pub oldest_relationship: Option<RelationshipId>,
}

/// Events that can occur in relationship management
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipEvent {
    /// A new relationship was established
    Established {
        id: RelationshipId,
        nickname: String,
        timestamp: u64,
    },
    /// Communication occurred with a relationship
    ContactMade {
        id: RelationshipId,
        timestamp: u64,
    },
    /// A relationship expired and was removed
    Expired {
        id: RelationshipId,
        nickname: String,
        last_contact: u64,
    },
    /// A relationship was manually removed
    Removed {
        id: RelationshipId,
        nickname: String,
    },
    /// Relationship settings were updated
    Updated {
        id: RelationshipId,
        changes: Vec<String>,
    },
}

impl Default for RelationshipConfig {
    fn default() -> Self {
        Self {
            max_relationships: 100, // Reasonable limit for handheld device
            default_timeout: 30 * 24 * 60 * 60, // 30 days
            auto_cleanup: true,
            cleanup_interval: 60 * 60, // 1 hour
        }
    }
}

impl RelationshipManager {
    /// Create a new relationship manager
    pub fn new(config: RelationshipConfig) -> Self {
        Self {
            relationships: HashMap::new(),
            config,
        }
    }

    /// Create with default configuration
    pub fn default() -> Self {
        Self::new(RelationshipConfig::default())
    }

    /// Add a new relationship
    pub fn add_relationship(&mut self, relationship: RelationshipContext) -> CryptoResult<()> {
        if self.relationships.len() >= self.config.max_relationships {
            return Err(CryptoError::Storage(
                "Maximum number of relationships reached".to_string()
            ));
        }

        let id = relationship.id.clone();
        self.relationships.insert(id, relationship);
        Ok(())
    }

    /// Get a relationship by ID
    pub fn get_relationship(&self, id: &RelationshipId) -> Option<&RelationshipContext> {
        self.relationships.get(id)
    }

    /// Get a mutable reference to a relationship
    pub fn get_relationship_mut(&mut self, id: &RelationshipId) -> Option<&mut RelationshipContext> {
        self.relationships.get_mut(id)
    }

    /// Update last contact time for a relationship
    pub fn update_last_contact(&mut self, id: &RelationshipId) -> CryptoResult<RelationshipEvent> {
        let relationship = self.relationships.get_mut(id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(id.0.clone()))?;

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        relationship.last_contact = now;

        Ok(RelationshipEvent::ContactMade {
            id: id.clone(),
            timestamp: now,
        })
    }

    /// Remove a relationship
    pub fn remove_relationship(&mut self, id: &RelationshipId) -> Option<RelationshipContext> {
        self.relationships.remove(id)
    }

    /// Get all active relationships
    pub fn get_all_relationships(&self) -> Vec<&RelationshipContext> {
        self.relationships.values().collect()
    }

    /// Get relationships sorted by last contact (most recent first)
    pub fn get_relationships_by_recent_contact(&self) -> Vec<&RelationshipContext> {
        let mut relationships: Vec<_> = self.relationships.values().collect();
        relationships.sort_by(|a, b| b.last_contact.cmp(&a.last_contact));
        relationships
    }

    /// Get relationships that have expired
    pub fn get_expired_relationships(&self) -> Vec<&RelationshipContext> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        self.relationships.values()
            .filter(|rel| {
                rel.auto_forget && 
                (now - rel.last_contact) > self.config.default_timeout
            })
            .collect()
    }

    /// Clean up expired relationships
    pub fn cleanup_expired(&mut self) -> CryptoResult<Vec<RelationshipEvent>> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut events = Vec::new();
        let mut to_remove = Vec::new();

        for (id, relationship) in &self.relationships {
            if relationship.auto_forget && 
               (now - relationship.last_contact) > self.config.default_timeout {
                to_remove.push(id.clone());
                events.push(RelationshipEvent::Expired {
                    id: id.clone(),
                    nickname: relationship.nickname.clone(),
                    last_contact: relationship.last_contact,
                });
            }
        }

        for id in to_remove {
            self.relationships.remove(&id);
        }

        Ok(events)
    }

    /// Update relationship nickname
    pub fn update_nickname(&mut self, id: &RelationshipId, new_nickname: String) -> CryptoResult<RelationshipEvent> {
        let relationship = self.relationships.get_mut(id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(id.0.clone()))?;

        relationship.nickname = new_nickname;

        Ok(RelationshipEvent::Updated {
            id: id.clone(),
            changes: vec!["nickname".to_string()],
        })
    }

    /// Update auto-forget setting for a relationship
    pub fn update_auto_forget(&mut self, id: &RelationshipId, auto_forget: bool) -> CryptoResult<RelationshipEvent> {
        let relationship = self.relationships.get_mut(id)
            .ok_or_else(|| CryptoError::RelationshipNotFound(id.0.clone()))?;

        relationship.auto_forget = auto_forget;

        Ok(RelationshipEvent::Updated {
            id: id.clone(),
            changes: vec!["auto_forget".to_string()],
        })
    }

    /// Find relationships by nickname (partial match)
    pub fn find_by_nickname(&self, partial_nickname: &str) -> Vec<&RelationshipContext> {
        let search_term = partial_nickname.to_lowercase();
        self.relationships.values()
            .filter(|rel| rel.nickname.to_lowercase().contains(&search_term))
            .collect()
    }

    /// Get relationship statistics
    pub fn get_statistics(&self) -> RelationshipStats {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let total_relationships = self.relationships.len();
        let auto_forget_count = self.relationships.values()
            .filter(|rel| rel.auto_forget)
            .count();

        let expired_count = self.relationships.values()
            .filter(|rel| {
                rel.auto_forget && 
                (now - rel.last_contact) > self.config.default_timeout
            })
            .count();

        let average_age = if total_relationships > 0 {
            let total_age: u64 = self.relationships.values()
                .map(|rel| now - rel.created_at)
                .sum();
            total_age as f64 / total_relationships as f64
        } else {
            0.0
        };

        let most_recent_contact = self.relationships.iter()
            .max_by_key(|(_, rel)| rel.last_contact)
            .map(|(id, _)| id.clone());

        let oldest_relationship = self.relationships.iter()
            .min_by_key(|(_, rel)| rel.created_at)
            .map(|(id, _)| id.clone());

        RelationshipStats {
            total_relationships,
            auto_forget_count,
            expired_count,
            average_age,
            most_recent_contact,
            oldest_relationship,
        }
    }

    /// Export all relationships for backup
    pub fn export_relationships(&self) -> CryptoResult<Vec<RelationshipContext>> {
        Ok(self.relationships.values().cloned().collect())
    }

    /// Import relationships from backup
    pub fn import_relationships(&mut self, relationships: Vec<RelationshipContext>) -> CryptoResult<Vec<RelationshipEvent>> {
        let mut events = Vec::new();

        for relationship in relationships {
            if self.relationships.len() >= self.config.max_relationships {
                break; // Stop if we hit the limit
            }

            let id = relationship.id.clone();
            let nickname = relationship.nickname.clone();
            let timestamp = relationship.created_at;

            self.relationships.insert(id.clone(), relationship);

            events.push(RelationshipEvent::Established {
                id,
                nickname,
                timestamp,
            });
        }

        Ok(events)
    }

    /// Check if a relationship exists
    pub fn has_relationship(&self, id: &RelationshipId) -> bool {
        self.relationships.contains_key(id)
    }

    /// Get the number of active relationships
    pub fn count(&self) -> usize {
        self.relationships.len()
    }

    /// Check if we're at the relationship limit
    pub fn is_at_limit(&self) -> bool {
        self.relationships.len() >= self.config.max_relationships
    }

    /// Get relationships that haven't been contacted recently
    pub fn get_stale_relationships(&self, days: u64) -> Vec<&RelationshipContext> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        let stale_threshold = days * 24 * 60 * 60;

        self.relationships.values()
            .filter(|rel| (now - rel.last_contact) > stale_threshold)
            .collect()
    }

    /// Force removal of oldest relationships to make room for new ones
    pub fn make_room_for_new(&mut self, count: usize) -> Vec<RelationshipEvent> {
        if self.relationships.len() + count <= self.config.max_relationships {
            return Vec::new(); // No need to remove anything
        }

        let to_remove = self.relationships.len() + count - self.config.max_relationships;
        let mut events = Vec::new();

        // Remove oldest auto-forget relationships first
        let candidates: Vec<_> = self.relationships.iter()
            .filter(|(_, rel)| rel.auto_forget)
            .map(|(id, rel)| (id.clone(), rel.last_contact, rel.nickname.clone()))
            .collect();
        
        let mut sorted_candidates = candidates;
        sorted_candidates.sort_by_key(|(_, last_contact, _)| *last_contact);

        for (id, _, nickname) in sorted_candidates.into_iter().take(to_remove) {
            self.relationships.remove(&id);
            events.push(RelationshipEvent::Removed { id, nickname });
        }

        events
    }
}

impl RelationshipContext {
    /// Check if this relationship has expired
    pub fn is_expired(&self, timeout: u64) -> bool {
        if !self.auto_forget {
            return false;
        }

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        (now - self.last_contact) > timeout
    }

    /// Get the age of this relationship in seconds
    pub fn age(&self) -> u64 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        now - self.created_at
    }

    /// Get time since last contact in seconds
    pub fn time_since_last_contact(&self) -> u64 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        now - self.last_contact
    }

    /// Update the last contact time to now
    pub fn touch(&mut self) {
        self.last_contact = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::{RelationshipKeypair, PublicKey};

    fn create_test_relationship(nickname: &str) -> RelationshipContext {
        let keypair = RelationshipKeypair::generate().unwrap();
        let peer_keypair = RelationshipKeypair::generate().unwrap();
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        RelationshipContext {
            id: RelationshipId(format!("test_{}", nickname)),
            nickname: nickname.to_string(),
            keypair,
            peer_public_key: peer_keypair.public_key,
            created_at: now,
            last_contact: now,
            auto_forget: true,
        }
    }

    #[test]
    fn test_relationship_manager_basic() {
        let mut manager = RelationshipManager::default();
        let relationship = create_test_relationship("alice");
        let id = relationship.id.clone();

        manager.add_relationship(relationship).unwrap();
        assert!(manager.has_relationship(&id));
        assert_eq!(manager.count(), 1);
    }

    #[test]
    fn test_relationship_expiration() {
        let manager = RelationshipManager::default();
        let mut relationship = create_test_relationship("bob");
        
        // Set last contact to a very old time
        relationship.last_contact = 1000000; // Very old timestamp
        
        assert!(relationship.is_expired(manager.config.default_timeout));
    }

    #[test]
    fn test_relationship_search() {
        let mut manager = RelationshipManager::default();
        
        manager.add_relationship(create_test_relationship("alice")).unwrap();
        manager.add_relationship(create_test_relationship("bob")).unwrap();
        manager.add_relationship(create_test_relationship("alice_2")).unwrap();

        let results = manager.find_by_nickname("alice");
        assert_eq!(results.len(), 2);
    }

    #[test]
    fn test_relationship_statistics() {
        let mut manager = RelationshipManager::default();
        
        manager.add_relationship(create_test_relationship("alice")).unwrap();
        manager.add_relationship(create_test_relationship("bob")).unwrap();

        let stats = manager.get_statistics();
        assert_eq!(stats.total_relationships, 2);
        assert_eq!(stats.auto_forget_count, 2);
        assert!(stats.most_recent_contact.is_some());
    }
}