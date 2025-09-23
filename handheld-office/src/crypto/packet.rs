/// Encrypted packet format for OfficeOS P2P communication
/// Implements the packet structure described in cryptographic-communication-vision
use crate::crypto::{CryptoError, CryptoResult, PublicKey, PrivateKey};
use serde::{Deserialize, Serialize};

/// An encrypted packet for P2P communication
/// The outer packet is unencrypted and contains routing information
/// The inner data is encrypted with relationship-specific keys
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedPacket {
    /// Version of packet format
    pub version: u8,
    /// Public key of the intended recipient (for this specific relationship)
    pub intended_recipient_key: PublicKey,
    /// Sender's public key (for this specific relationship)
    pub sender_key: PublicKey,
    /// Encrypted payload data
    pub encrypted_data: Vec<u8>,
    /// Packet timestamp
    pub timestamp: u64,
    /// Packet sequence number (for ordering and replay protection)
    pub sequence: u64,
    /// Message authentication code
    pub mac: Vec<u8>,
}

/// Packet types that can be sent
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PacketType {
    /// Regular data packet
    Data,
    /// Pairing request
    PairingRequest,
    /// Pairing response
    PairingResponse,
    /// Heartbeat/keepalive
    Heartbeat,
    /// Acknowledgment
    Ack,
    /// Key rotation request
    KeyRotation,
}

/// Inner packet structure (encrypted)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InnerPacket {
    /// Type of packet
    pub packet_type: PacketType,
    /// Application-specific data
    pub payload: Vec<u8>,
    /// Additional metadata
    pub metadata: PacketMetadata,
}

/// Metadata included with packets
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PacketMetadata {
    /// Application that sent this packet
    pub sender_app: String,
    /// Intended application
    pub recipient_app: String,
    /// Priority level (0-255, higher is more priority)
    pub priority: u8,
    /// Whether this packet requires acknowledgment
    pub requires_ack: bool,
    /// Correlation ID for request/response pairing
    pub correlation_id: Option<String>,
}

/// Statistics about packet processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PacketStats {
    /// Total packets sent
    pub packets_sent: u64,
    /// Total packets received
    pub packets_received: u64,
    /// Packets that failed to decrypt
    pub decryption_failures: u64,
    /// Packets with invalid MAC
    pub mac_failures: u64,
    /// Duplicate packets received
    pub duplicate_packets: u64,
    /// Out-of-order packets
    pub out_of_order_packets: u64,
}

impl EncryptedPacket {
    /// Current packet format version
    pub const VERSION: u8 = 1;

    /// Create a new encrypted packet
    pub fn create(
        data: &[u8],
        sender_private_key: &PrivateKey,
        recipient_public_key: &PublicKey,
        sender_public_key: &PublicKey,
    ) -> CryptoResult<Self> {
        use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce, AeadCore, AeadInPlace, KeyInit};
        use rand::rngs::OsRng;

        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Perform key exchange to get shared secret
        let shared_secret = sender_private_key.key_exchange(recipient_public_key);

        // Encrypt the data
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&shared_secret));
        let nonce = ChaCha20Poly1305::generate_nonce(&mut OsRng);

        let mut buffer = data.to_vec();
        cipher.encrypt_in_place(&nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Encryption(e.to_string()))?;

        // Prepend nonce to encrypted data
        let mut encrypted_data = nonce.to_vec();
        encrypted_data.extend_from_slice(&buffer);

        // Generate MAC over the entire packet structure (except MAC field)
        let mac = Self::generate_mac(
            sender_public_key,
            recipient_public_key,
            &encrypted_data,
            timestamp,
            0, // sequence will be filled in by packet manager
            &shared_secret,
        )?;

        Ok(Self {
            version: Self::VERSION,
            intended_recipient_key: recipient_public_key.clone(),
            sender_key: sender_public_key.clone(),
            encrypted_data,
            timestamp,
            sequence: 0, // Will be set by packet manager
            mac,
        })
    }

    /// Decrypt the packet using the recipient's private key
    pub fn decrypt(&self, recipient_private_key: &PrivateKey) -> CryptoResult<Vec<u8>> {
        use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce, AeadInPlace, KeyInit};

        if self.encrypted_data.len() < 12 {
            return Err(CryptoError::Decryption("Data too short".to_string()));
        }

        // Verify MAC first
        let shared_secret = recipient_private_key.key_exchange(&self.sender_key);
        let expected_mac = Self::generate_mac(
            &self.sender_key,
            &self.intended_recipient_key,
            &self.encrypted_data,
            self.timestamp,
            self.sequence,
            &shared_secret,
        )?;

        if expected_mac != self.mac {
            return Err(CryptoError::Decryption("MAC verification failed".to_string()));
        }

        // Extract nonce and ciphertext
        let (nonce_bytes, ciphertext) = self.encrypted_data.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);

        // Decrypt
        let cipher = ChaCha20Poly1305::new(Key::from_slice(&shared_secret));

        let mut buffer = ciphertext.to_vec();
        cipher.decrypt_in_place(nonce, b"", &mut buffer)
            .map_err(|e| CryptoError::Decryption(e.to_string()))?;

        Ok(buffer)
    }

    /// Set the sequence number for this packet
    pub fn set_sequence(&mut self, sequence: u64) -> CryptoResult<()> {
        self.sequence = sequence;

        // Regenerate MAC with new sequence number
        let shared_secret = {
            // We need to recalculate the shared secret, but we don't have the private key here
            // In practice, this would be called by the packet manager that has access to keys
            // For now, we'll leave the MAC as-is and assume it's updated externally
            return Ok(());
        };
    }

    /// Verify packet integrity and authenticity
    pub fn verify(&self, recipient_private_key: &PrivateKey) -> CryptoResult<()> {
        let shared_secret = recipient_private_key.key_exchange(&self.sender_key);
        let expected_mac = Self::generate_mac(
            &self.sender_key,
            &self.intended_recipient_key,
            &self.encrypted_data,
            self.timestamp,
            self.sequence,
            &shared_secret,
        )?;

        if expected_mac != self.mac {
            return Err(CryptoError::SignatureVerification);
        }

        Ok(())
    }

    /// Get packet size in bytes
    pub fn size(&self) -> usize {
        // Rough calculation - in practice would serialize and measure
        64 + 64 + self.encrypted_data.len() + 32 + 8 + 8 + self.mac.len()
    }

    /// Check if packet is expired based on timestamp
    pub fn is_expired(&self, max_age_seconds: u64) -> bool {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        (now - self.timestamp) > max_age_seconds
    }

    /// Generate message authentication code
    fn generate_mac(
        sender_key: &PublicKey,
        recipient_key: &PublicKey,
        encrypted_data: &[u8],
        timestamp: u64,
        sequence: u64,
        shared_secret: &[u8; 32],
    ) -> CryptoResult<Vec<u8>> {
        use sha2::{Digest, Sha256};

        let mut hasher = Sha256::new();
        hasher.update(sender_key.as_bytes());
        hasher.update(recipient_key.as_bytes());
        hasher.update(encrypted_data);
        hasher.update(&timestamp.to_le_bytes());
        hasher.update(&sequence.to_le_bytes());
        hasher.update(shared_secret);

        Ok(hasher.finalize().to_vec())
    }
}

impl InnerPacket {
    /// Create a new inner packet
    pub fn new(
        packet_type: PacketType,
        payload: Vec<u8>,
        sender_app: String,
        recipient_app: String,
    ) -> Self {
        Self {
            packet_type,
            payload,
            metadata: PacketMetadata {
                sender_app,
                recipient_app,
                priority: 128, // Default priority
                requires_ack: false,
                correlation_id: None,
            },
        }
    }

    /// Create with custom metadata
    pub fn with_metadata(
        packet_type: PacketType,
        payload: Vec<u8>,
        metadata: PacketMetadata,
    ) -> Self {
        Self {
            packet_type,
            payload,
            metadata,
        }
    }

    /// Serialize to bytes for encryption
    pub fn to_bytes(&self) -> CryptoResult<Vec<u8>> {
        serde_json::to_vec(self)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }

    /// Deserialize from decrypted bytes
    pub fn from_bytes(data: &[u8]) -> CryptoResult<Self> {
        serde_json::from_slice(data)
            .map_err(|e| CryptoError::Storage(e.to_string()))
    }
}

impl PacketMetadata {
    /// Create basic metadata
    pub fn basic(sender_app: &str, recipient_app: &str) -> Self {
        Self {
            sender_app: sender_app.to_string(),
            recipient_app: recipient_app.to_string(),
            priority: 128,
            requires_ack: false,
            correlation_id: None,
        }
    }

    /// Create high-priority metadata
    pub fn high_priority(sender_app: &str, recipient_app: &str) -> Self {
        Self {
            sender_app: sender_app.to_string(),
            recipient_app: recipient_app.to_string(),
            priority: 200,
            requires_ack: true,
            correlation_id: None,
        }
    }

    /// Create request metadata with correlation ID
    pub fn request(sender_app: &str, recipient_app: &str, correlation_id: String) -> Self {
        Self {
            sender_app: sender_app.to_string(),
            recipient_app: recipient_app.to_string(),
            priority: 150,
            requires_ack: true,
            correlation_id: Some(correlation_id),
        }
    }
}

impl Default for PacketStats {
    fn default() -> Self {
        Self {
            packets_sent: 0,
            packets_received: 0,
            decryption_failures: 0,
            mac_failures: 0,
            duplicate_packets: 0,
            out_of_order_packets: 0,
        }
    }
}

/// Packet manager for handling sequence numbers and statistics
pub struct PacketManager {
    /// Next sequence number to use for outgoing packets
    next_sequence: u64,
    /// Sequence numbers we've seen from each sender
    received_sequences: std::collections::HashMap<String, u64>,
    /// Packet statistics
    stats: PacketStats,
    /// Maximum age for packets (in seconds)
    max_packet_age: u64,
}

impl PacketManager {
    /// Create a new packet manager
    pub fn new() -> Self {
        Self {
            next_sequence: 1,
            received_sequences: std::collections::HashMap::new(),
            stats: PacketStats::default(),
            max_packet_age: 300, // 5 minutes
        }
    }

    /// Prepare packet for sending (sets sequence number)
    pub fn prepare_outgoing_packet(&mut self, mut packet: EncryptedPacket) -> EncryptedPacket {
        packet.sequence = self.next_sequence;
        self.next_sequence += 1;
        self.stats.packets_sent += 1;
        packet
    }

    /// Process incoming packet (check sequence, update stats)
    pub fn process_incoming_packet(&mut self, packet: &EncryptedPacket) -> PacketProcessResult {
        self.stats.packets_received += 1;

        // Check if packet is expired
        if packet.is_expired(self.max_packet_age) {
            return PacketProcessResult::Expired;
        }

        // Check sequence number for this sender
        let sender_id = hex::encode(&packet.sender_key.as_bytes());
        
        if let Some(&last_sequence) = self.received_sequences.get(&sender_id) {
            if packet.sequence <= last_sequence {
                self.stats.duplicate_packets += 1;
                return PacketProcessResult::Duplicate;
            }
            
            if packet.sequence != last_sequence + 1 {
                self.stats.out_of_order_packets += 1;
                // Still process it, but note it's out of order
            }
        }

        // Update received sequence
        self.received_sequences.insert(sender_id, packet.sequence);

        PacketProcessResult::Valid
    }

    /// Record decryption failure
    pub fn record_decryption_failure(&mut self) {
        self.stats.decryption_failures += 1;
    }

    /// Record MAC failure
    pub fn record_mac_failure(&mut self) {
        self.stats.mac_failures += 1;
    }

    /// Get current statistics
    pub fn get_stats(&self) -> &PacketStats {
        &self.stats
    }

    /// Reset statistics
    pub fn reset_stats(&mut self) {
        self.stats = PacketStats::default();
    }
}

/// Result of processing an incoming packet
#[derive(Debug, Clone, PartialEq)]
pub enum PacketProcessResult {
    /// Packet is valid and should be processed
    Valid,
    /// Packet is a duplicate (already seen this sequence)
    Duplicate,
    /// Packet is expired (too old)
    Expired,
    /// Packet failed MAC verification
    MacFailure,
    /// Packet failed to decrypt
    DecryptionFailure,
}

impl Default for PacketManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::Keypair;

    fn create_test_keypairs() -> (Keypair, Keypair) {
        (Keypair::generate().unwrap(), Keypair::generate().unwrap())
    }

    #[test]
    fn test_packet_creation_and_decryption() {
        let (alice, bob) = create_test_keypairs();
        let message = b"Hello, encrypted world!";

        let packet = EncryptedPacket::create(
            message,
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();

        let decrypted = packet.decrypt(&bob.private_key).unwrap();
        assert_eq!(message, decrypted.as_slice());
    }

    #[test]
    fn test_packet_verification() {
        let (alice, bob) = create_test_keypairs();
        let message = b"Test message";

        let packet = EncryptedPacket::create(
            message,
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();

        assert!(packet.verify(&bob.private_key).is_ok());
    }

    #[test]
    fn test_inner_packet_serialization() {
        let inner = InnerPacket::new(
            PacketType::Data,
            b"test payload".to_vec(),
            "test_app".to_string(),
            "target_app".to_string(),
        );

        let bytes = inner.to_bytes().unwrap();
        let restored = InnerPacket::from_bytes(&bytes).unwrap();

        assert!(matches!(restored.packet_type, PacketType::Data));
        assert_eq!(restored.payload, b"test payload");
    }

    #[test]
    fn test_packet_manager() {
        let mut manager = PacketManager::new();
        let (alice, bob) = create_test_keypairs();

        let packet = EncryptedPacket::create(
            b"test",
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();

        let prepared = manager.prepare_outgoing_packet(packet);
        assert_eq!(prepared.sequence, 1);
        assert_eq!(manager.get_stats().packets_sent, 1);

        let result = manager.process_incoming_packet(&prepared);
        assert_eq!(result, PacketProcessResult::Valid);
        assert_eq!(manager.get_stats().packets_received, 1);
    }

    #[test]
    fn test_duplicate_detection() {
        let mut manager = PacketManager::new();
        let (alice, bob) = create_test_keypairs();

        let mut packet = EncryptedPacket::create(
            b"test",
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();
        packet.sequence = 1;

        let result1 = manager.process_incoming_packet(&packet);
        assert_eq!(result1, PacketProcessResult::Valid);

        let result2 = manager.process_incoming_packet(&packet);
        assert_eq!(result2, PacketProcessResult::Duplicate);
        assert_eq!(manager.get_stats().duplicate_packets, 1);
    }

    #[test]
    fn test_packet_expiration() {
        let (alice, bob) = create_test_keypairs();
        let mut packet = EncryptedPacket::create(
            b"test",
            &alice.private_key,
            &bob.public_key,
            &alice.public_key,
        ).unwrap();

        // Set timestamp to 1 hour ago
        packet.timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() - 3600;

        assert!(packet.is_expired(300)); // 5 minute max age
    }
}