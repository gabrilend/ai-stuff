/// Emoji-based device pairing protocol for OfficeOS
/// Implements the pairing system described in cryptographic-communication-vision
use crate::crypto::{CryptoError, CryptoResult, PublicKey};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH, Duration};

/// An emoji used for device pairing identification
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PairingEmoji {
    /// Unicode emoji character
    pub emoji: String,
    /// Text description for terminals that don't support emoji
    pub description: String,
    /// Unique identifier for this pairing session
    pub session_id: String,
    /// Public key of the device broadcasting this emoji
    pub device_public_key: PublicKey,
    /// When this emoji was first broadcast
    pub first_seen: u64,
    /// Last time we saw this emoji being broadcast
    pub last_seen: u64,
    /// Signal strength or proximity indicator (0-100)
    pub signal_strength: u8,
}

/// Current state of the pairing manager
#[derive(Debug, Clone, PartialEq)]
pub enum PairingState {
    /// Not in pairing mode
    Idle,
    /// Broadcasting our emoji and scanning for others
    Active {
        our_emoji: PairingEmoji,
        start_time: u64,
    },
    /// Waiting for user to select a discovered device
    WaitingForSelection {
        our_emoji: PairingEmoji,
        discovered_devices: Vec<PairingEmoji>,
    },
    /// Completing pairing with a selected device
    Completing {
        our_emoji: PairingEmoji,
        target_emoji: PairingEmoji,
    },
}

/// Manager for emoji-based device pairing
pub struct PairingManager {
    /// Our device's public key
    device_public_key: PublicKey,
    /// Current pairing state
    state: PairingState,
    /// Discovered devices indexed by session ID
    discovered_devices: HashMap<String, PairingEmoji>,
    /// Configuration for pairing
    config: PairingConfig,
    /// Available emoji pool
    emoji_pool: Vec<EmojiData>,
}

/// Configuration for pairing behavior
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairingConfig {
    /// How long to stay in pairing mode (seconds)
    pub pairing_timeout: u64,
    /// How long to remember discovered devices (seconds)
    pub discovery_timeout: u64,
    /// How often to broadcast our emoji (seconds)
    pub broadcast_interval: u64,
    /// Minimum signal strength to consider a device
    pub min_signal_strength: u8,
    /// Maximum number of devices to track
    pub max_discovered_devices: usize,
}

/// Static emoji data
#[derive(Debug, Clone, Serialize, Deserialize)]
struct EmojiData {
    emoji: String,
    description: String,
    category: String,
}

impl Default for PairingConfig {
    fn default() -> Self {
        Self {
            pairing_timeout: 300, // 5 minutes
            discovery_timeout: 30, // 30 seconds
            broadcast_interval: 2, // 2 seconds
            min_signal_strength: 20,
            max_discovered_devices: 20,
        }
    }
}

impl PairingManager {
    /// Create a new pairing manager
    pub fn new(device_public_key: PublicKey) -> Self {
        Self {
            device_public_key,
            state: PairingState::Idle,
            discovered_devices: HashMap::new(),
            config: PairingConfig::default(),
            emoji_pool: Self::create_emoji_pool(),
        }
    }

    /// Create pairing manager with custom configuration
    pub fn with_config(device_public_key: PublicKey, config: PairingConfig) -> Self {
        Self {
            device_public_key,
            state: PairingState::Idle,
            discovered_devices: HashMap::new(),
            config,
            emoji_pool: Self::create_emoji_pool(),
        }
    }

    /// Enter pairing mode and start broadcasting our emoji
    pub fn enter_pairing_mode(&mut self) -> CryptoResult<PairingEmoji> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Generate random emoji for this pairing session
        let emoji_data = self.select_random_emoji()?;
        let session_id = self.generate_session_id();

        let our_emoji = PairingEmoji {
            emoji: emoji_data.emoji.clone(),
            description: emoji_data.description.clone(),
            session_id,
            device_public_key: self.device_public_key.clone(),
            first_seen: now,
            last_seen: now,
            signal_strength: 100, // We always have perfect signal to ourselves
        };

        self.state = PairingState::Active {
            our_emoji: our_emoji.clone(),
            start_time: now,
        };

        // Clear previous discoveries
        self.discovered_devices.clear();

        Ok(our_emoji)
    }

    /// Exit pairing mode
    pub fn exit_pairing_mode(&mut self) {
        self.state = PairingState::Idle;
        self.discovered_devices.clear();
    }

    /// Report a discovered device broadcasting an emoji
    pub fn report_discovered_device(&mut self, emoji: PairingEmoji) -> CryptoResult<()> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Don't discover our own emoji
        if let PairingState::Active { our_emoji, .. } = &self.state {
            if emoji.session_id == our_emoji.session_id {
                return Ok(());
            }
        }

        // Check signal strength
        if emoji.signal_strength < self.config.min_signal_strength {
            return Ok(());
        }

        // Update or add discovered device
        if let Some(existing) = self.discovered_devices.get_mut(&emoji.session_id) {
            existing.last_seen = now;
            existing.signal_strength = emoji.signal_strength;
        } else {
            // Check if we're at capacity
            if self.discovered_devices.len() >= self.config.max_discovered_devices {
                // Remove oldest device
                self.remove_oldest_discovered_device();
            }

            let mut new_emoji = emoji;
            new_emoji.first_seen = now;
            new_emoji.last_seen = now;
            
            self.discovered_devices.insert(new_emoji.session_id.clone(), new_emoji);
        }

        Ok(())
    }

    /// Get list of currently discovered devices
    pub fn get_discovered_devices(&mut self) -> Vec<PairingEmoji> {
        self.cleanup_expired_discoveries();
        self.discovered_devices.values().cloned().collect()
    }

    /// Get our current emoji (if in pairing mode)
    pub fn get_our_emoji(&self) -> Option<&PairingEmoji> {
        match &self.state {
            PairingState::Active { our_emoji, .. } |
            PairingState::WaitingForSelection { our_emoji, .. } |
            PairingState::Completing { our_emoji, .. } => Some(our_emoji),
            PairingState::Idle => None,
        }
    }

    /// Start pairing process with a selected device
    pub fn select_device_for_pairing(&mut self, target_emoji: &PairingEmoji) -> CryptoResult<()> {
        match &self.state {
            PairingState::Active { our_emoji, .. } => {
                if !self.discovered_devices.contains_key(&target_emoji.session_id) {
                    return Err(CryptoError::Pairing("Device not found in discovered list".to_string()));
                }

                self.state = PairingState::Completing {
                    our_emoji: our_emoji.clone(),
                    target_emoji: target_emoji.clone(),
                };

                Ok(())
            }
            _ => Err(CryptoError::Pairing("Not in active pairing mode".to_string())),
        }
    }

    /// Complete the pairing process and return the peer's public key
    pub fn complete_pairing(&mut self, target_emoji: &PairingEmoji) -> CryptoResult<PublicKey> {
        match &self.state {
            PairingState::Completing { target_emoji: selected, .. } => {
                if selected.session_id != target_emoji.session_id {
                    return Err(CryptoError::Pairing("Target emoji mismatch".to_string()));
                }

                let peer_public_key = target_emoji.device_public_key.clone();
                
                // Exit pairing mode
                self.exit_pairing_mode();

                Ok(peer_public_key)
            }
            _ => Err(CryptoError::Pairing("Not in completing state".to_string())),
        }
    }

    /// Get current pairing state
    pub fn get_state(&self) -> &PairingState {
        &self.state
    }

    /// Update pairing manager (call periodically)
    pub fn update(&mut self) -> CryptoResult<Vec<PairingEvent>> {
        let mut events = Vec::new();

        // Check for timeout
        if let Some(event) = self.check_timeout()? {
            events.push(event);
        }

        // Clean up expired discoveries
        let expired = self.cleanup_expired_discoveries();
        for session_id in expired {
            events.push(PairingEvent::DeviceLost { session_id });
        }

        Ok(events)
    }

    /// Generate a unique session ID
    fn generate_session_id(&self) -> String {
        use rand::Rng;
        
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        
        let random: u32 = rand::thread_rng().gen();
        format!("{:x}_{:x}", now & 0xFFFFFFFF, random)
    }

    /// Select a random emoji from our pool
    fn select_random_emoji(&self) -> CryptoResult<&EmojiData> {
        use rand::Rng;
        
        if self.emoji_pool.is_empty() {
            return Err(CryptoError::Pairing("No emoji available".to_string()));
        }

        let index = rand::thread_rng().gen_range(0..self.emoji_pool.len());
        Ok(&self.emoji_pool[index])
    }

    /// Remove oldest discovered device to make room
    fn remove_oldest_discovered_device(&mut self) {
        if let Some((oldest_id, _)) = self.discovered_devices.iter()
            .min_by_key(|(_, emoji)| emoji.first_seen)
            .map(|(id, emoji)| (id.clone(), emoji.first_seen))
        {
            self.discovered_devices.remove(&oldest_id);
        }
    }

    /// Clean up expired discoveries and return list of expired session IDs
    fn cleanup_expired_discoveries(&mut self) -> Vec<String> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut expired = Vec::new();

        for (session_id, emoji) in &self.discovered_devices {
            if (now - emoji.last_seen) > self.config.discovery_timeout {
                expired.push(session_id.clone());
            }
        }

        for session_id in &expired {
            self.discovered_devices.remove(session_id);
        }

        expired
    }

    /// Check for pairing timeout
    fn check_timeout(&mut self) -> CryptoResult<Option<PairingEvent>> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        match &self.state {
            PairingState::Active { start_time, .. } => {
                if (now - start_time) > self.config.pairing_timeout {
                    self.exit_pairing_mode();
                    return Ok(Some(PairingEvent::PairingTimeout));
                }
            }
            _ => {}
        }

        Ok(None)
    }

    /// Create the pool of available emoji
    fn create_emoji_pool() -> Vec<EmojiData> {
        vec![
            // Faces
            EmojiData { emoji: "😀".to_string(), description: "grinning face".to_string(), category: "faces".to_string() },
            EmojiData { emoji: "😎".to_string(), description: "smiling face with sunglasses".to_string(), category: "faces".to_string() },
            EmojiData { emoji: "🤔".to_string(), description: "thinking face".to_string(), category: "faces".to_string() },
            EmojiData { emoji: "😊".to_string(), description: "smiling face with smiling eyes".to_string(), category: "faces".to_string() },
            EmojiData { emoji: "🙃".to_string(), description: "upside-down face".to_string(), category: "faces".to_string() },
            
            // Animals
            EmojiData { emoji: "🐱".to_string(), description: "cat face".to_string(), category: "animals".to_string() },
            EmojiData { emoji: "🐶".to_string(), description: "dog face".to_string(), category: "animals".to_string() },
            EmojiData { emoji: "🦊".to_string(), description: "fox".to_string(), category: "animals".to_string() },
            EmojiData { emoji: "🐸".to_string(), description: "frog".to_string(), category: "animals".to_string() },
            EmojiData { emoji: "🐧".to_string(), description: "penguin".to_string(), category: "animals".to_string() },
            
            // Objects
            EmojiData { emoji: "🎮".to_string(), description: "video game controller".to_string(), category: "objects".to_string() },
            EmojiData { emoji: "🔥".to_string(), description: "fire".to_string(), category: "objects".to_string() },
            EmojiData { emoji: "⭐".to_string(), description: "star".to_string(), category: "objects".to_string() },
            EmojiData { emoji: "🎯".to_string(), description: "direct hit".to_string(), category: "objects".to_string() },
            EmojiData { emoji: "🚀".to_string(), description: "rocket".to_string(), category: "objects".to_string() },
            
            // Food
            EmojiData { emoji: "🍕".to_string(), description: "pizza".to_string(), category: "food".to_string() },
            EmojiData { emoji: "🍔".to_string(), description: "hamburger".to_string(), category: "food".to_string() },
            EmojiData { emoji: "🍎".to_string(), description: "apple".to_string(), category: "food".to_string() },
            EmojiData { emoji: "☕".to_string(), description: "hot beverage".to_string(), category: "food".to_string() },
            EmojiData { emoji: "🍰".to_string(), description: "cake".to_string(), category: "food".to_string() },
            
            // Nature
            EmojiData { emoji: "🌟".to_string(), description: "glowing star".to_string(), category: "nature".to_string() },
            EmojiData { emoji: "🌙".to_string(), description: "crescent moon".to_string(), category: "nature".to_string() },
            EmojiData { emoji: "☀️".to_string(), description: "sun".to_string(), category: "nature".to_string() },
            EmojiData { emoji: "🌈".to_string(), description: "rainbow".to_string(), category: "nature".to_string() },
            EmojiData { emoji: "⚡".to_string(), description: "lightning".to_string(), category: "nature".to_string() },
            
            // Activities
            EmojiData { emoji: "🎪".to_string(), description: "circus tent".to_string(), category: "activities".to_string() },
            EmojiData { emoji: "🎨".to_string(), description: "artist palette".to_string(), category: "activities".to_string() },
            EmojiData { emoji: "🎵".to_string(), description: "musical note".to_string(), category: "activities".to_string() },
            EmojiData { emoji: "🎲".to_string(), description: "game die".to_string(), category: "activities".to_string() },
            EmojiData { emoji: "🏆".to_string(), description: "trophy".to_string(), category: "activities".to_string() },
        ]
    }
}

/// Events that can occur during pairing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PairingEvent {
    /// Pairing mode was entered
    PairingStarted { our_emoji: PairingEmoji },
    /// A new device was discovered
    DeviceDiscovered { emoji: PairingEmoji },
    /// A device was lost (stopped broadcasting)
    DeviceLost { session_id: String },
    /// Pairing was completed successfully
    PairingCompleted { 
        our_emoji: PairingEmoji, 
        peer_emoji: PairingEmoji 
    },
    /// Pairing timed out
    PairingTimeout,
    /// Pairing was cancelled
    PairingCancelled,
}

impl PairingEmoji {
    /// Check if this emoji has expired based on last seen time
    pub fn is_expired(&self, timeout_seconds: u64) -> bool {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        (now - self.last_seen) > timeout_seconds
    }

    /// Get age of this emoji in seconds
    pub fn age(&self) -> u64 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        now - self.first_seen
    }

    /// Create a display string for terminals that don't support emoji
    pub fn display_string(&self) -> String {
        format!("{} ({})", self.emoji, self.description)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::Keypair;

    fn create_test_keypair() -> PublicKey {
        Keypair::generate().unwrap().public_key
    }

    #[test]
    fn test_pairing_manager_creation() {
        let public_key = create_test_keypair();
        let manager = PairingManager::new(public_key);
        
        assert!(matches!(manager.get_state(), PairingState::Idle));
    }

    #[test]
    fn test_enter_pairing_mode() {
        let public_key = create_test_keypair();
        let mut manager = PairingManager::new(public_key);
        
        let emoji = manager.enter_pairing_mode().unwrap();
        
        assert!(!emoji.emoji.is_empty());
        assert!(!emoji.description.is_empty());
        assert!(matches!(manager.get_state(), PairingState::Active { .. }));
    }

    #[test]
    fn test_discover_device() {
        let public_key = create_test_keypair();
        let mut manager = PairingManager::new(public_key.clone());
        
        manager.enter_pairing_mode().unwrap();

        // Create a fake discovered device
        let peer_key = create_test_keypair();
        let discovered_emoji = PairingEmoji {
            emoji: "🐱".to_string(),
            description: "cat face".to_string(),
            session_id: "test_session".to_string(),
            device_public_key: peer_key,
            first_seen: 0,
            last_seen: 0,
            signal_strength: 50,
        };

        manager.report_discovered_device(discovered_emoji).unwrap();
        
        let discovered = manager.get_discovered_devices();
        assert_eq!(discovered.len(), 1);
        assert_eq!(discovered[0].emoji, "🐱");
    }

    #[test]
    fn test_emoji_expiration() {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let emoji = PairingEmoji {
            emoji: "🐱".to_string(),
            description: "cat".to_string(),
            session_id: "test".to_string(),
            device_public_key: create_test_keypair(),
            first_seen: now - 100,
            last_seen: now - 50,
            signal_strength: 50,
        };

        assert!(!emoji.is_expired(60)); // Not expired
        assert!(emoji.is_expired(40));  // Expired
    }

    #[test]
    fn test_signal_strength_filtering() {
        let public_key = create_test_keypair();
        let mut manager = PairingManager::new(public_key.clone());
        
        manager.enter_pairing_mode().unwrap();

        // Create device with low signal strength
        let weak_device = PairingEmoji {
            emoji: "🐱".to_string(),
            description: "cat face".to_string(),
            session_id: "weak_session".to_string(),
            device_public_key: create_test_keypair(),
            first_seen: 0,
            last_seen: 0,
            signal_strength: 10, // Below default minimum of 20
        };

        manager.report_discovered_device(weak_device).unwrap();
        
        let discovered = manager.get_discovered_devices();
        assert_eq!(discovered.len(), 0); // Should be filtered out
    }
}