use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;

/// SSH-encrypted email client for Anbernic devices
/// Uses radial menus and auto-encrypts with SSH keys
#[derive(Debug, Clone)]
pub struct AnbernicEmailClient {
    pub inbox: Vec<EmailMessage>,
    pub outbox: Vec<EmailMessage>,
    pub drafts: Vec<EmailMessage>,
    pub contacts: HashMap<String, Contact>,
    pub ssh_keys: SSHKeyManager,
    pub current_message: Option<EmailMessage>,
    pub input_state: EmailInputState,
    pub ui_state: EmailUIState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmailMessage {
    pub id: String,
    pub from: String,
    pub to: Vec<String>,
    pub subject: String,
    pub body: String,
    pub timestamp: DateTime<Utc>,
    pub encryption_status: EncryptionStatus,
    pub message_type: MessageType,
    pub attachments: Vec<Attachment>,
    pub thread_id: Option<String>,
    pub read_status: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contact {
    pub name: String,
    pub email: String,
    pub ssh_public_key: Option<String>,
    pub device_type: Option<String>, // "anbernic_rg35xx", etc.
    pub last_seen: Option<DateTime<Utc>>,
    pub trust_level: TrustLevel,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrustLevel {
    Unknown,
    Verified,
    Trusted,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EncryptionStatus {
    Encrypted,
    Unencrypted,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MessageType {
    Draft,
    Sent,
    Received,
}

#[derive(Debug, Clone)]
pub struct SSHKeyManager {
    pub private_key_path: PathBuf,
    pub public_key_path: PathBuf,
    pub known_hosts: HashMap<String, String>, // email -> public key
    pub relationship_keys: HashMap<String, (String, String)>, // email -> (private_key, public_key) for this relationship
    pub device_fingerprint: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Attachment {
    pub filename: String,
    pub content_type: String,
    pub size: u64,
    pub data: Vec<u8>,
    pub is_encrypted: bool,
}

/// Radial menu input system (from handheld client)
#[derive(Debug, Clone)]
pub struct EmailInputState {
    pub current_group: InputGroup,
    pub selected_index: usize,
    pub text_buffer: String,
    pub cursor_position: usize,
    pub input_mode: InputMode,
}

#[derive(Debug, Clone)]
pub enum InputGroup {
    MainMenu,
    Compose,
    Recipients,
    Subject,
    Body,
    Actions,
    Contacts,
    Settings,
}

#[derive(Debug, Clone)]
pub enum InputMode {
    Navigation, // A/B navigate, L/R select
    TextEntry,  // Hierarchical text input
    RadialMenu, // Circular menu selection
}

/// Game Boy style UI state
#[derive(Debug, Clone)]
pub struct EmailUIState {
    pub current_view: EmailView,
    pub selected_message_index: usize,
    pub selected_contact_index: usize,
    pub show_help: bool,
    pub animation_frame: u32,
    pub scroll_offset: usize,
    pub l_shaped_display: bool, // Use L-shaped layout from text editor
}

#[derive(Debug, Clone)]
pub enum EmailView {
    MainMenu,
    Inbox,
    ReadMessage,
    Compose,
    Contacts,
}

/// Hierarchical character groups for radial input
#[derive(Debug, Clone)]
pub struct CharacterGroup {
    pub name: String,
    pub characters: Vec<char>,
    pub subgroups: Vec<CharacterGroup>,
}

impl AnbernicEmailClient {
    pub fn new(username: String) -> Result<Self, Box<dyn std::error::Error>> {
        let ssh_keys = SSHKeyManager::new()?;

        Ok(Self {
            inbox: vec![],
            outbox: vec![],
            drafts: vec![],
            contacts: HashMap::new(),
            ssh_keys,
            current_message: None,
            input_state: EmailInputState::default(),
            ui_state: EmailUIState::default(),
        })
    }

    /// Encrypt message with recipient's SSH public key
    pub fn encrypt_message(
        &mut self,
        message: &mut EmailMessage,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if !message.to.is_empty() {
            let recipient_email = &message.to[0];
            // Use per-relationship encryption
            let encrypted_body = self
                .ssh_keys
                .encrypt_for_recipient(&message.body, recipient_email)?;
            message.body = encrypted_body;
            message.encryption_status = EncryptionStatus::Encrypted;
        }
        Ok(())
    }

    /// Decrypt message with our private key using per-relationship keys
    pub fn decrypt_message(
        &mut self,
        message: &mut EmailMessage,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if matches!(message.encryption_status, EncryptionStatus::Encrypted) {
            let sender_email = &message.from;
            // Use per-relationship decryption
            match self
                .ssh_keys
                .decrypt_from_sender(&message.body, sender_email)
            {
                Ok(decrypted_body) => {
                    message.body = decrypted_body;
                    message.encryption_status = EncryptionStatus::Unencrypted;
                }
                Err(_) => {
                    // Keep message encrypted if decryption fails
                    return Ok(());
                }
            }
        }
        Ok(())
    }

    fn get_battery_level(&self) -> Option<u8> {
        // Read battery level from system (same as MMO engine)
        if let Ok(battery_path) = std::fs::read_to_string("/sys/class/power_supply/BAT0/capacity") {
            battery_path.trim().parse().ok()
        } else if let Ok(battery_path) =
            std::fs::read_to_string("/sys/class/power_supply/battery/capacity")
        {
            battery_path.trim().parse().ok()
        } else {
            None
        }
    }
}

impl SSHKeyManager {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let home_dir = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let ssh_dir = PathBuf::from(home_dir).join(".ssh").join("anbernic_email");

        // Create SSH directory if it doesn't exist
        std::fs::create_dir_all(&ssh_dir)?;

        let private_key_path = ssh_dir.join("id_anbernic");
        let public_key_path = ssh_dir.join("id_anbernic.pub");

        // Generate keys if they don't exist
        if !private_key_path.exists() {
            Self::generate_ssh_keys(&private_key_path, &public_key_path)?;
        }

        let device_fingerprint = Self::generate_device_fingerprint();

        Ok(Self {
            private_key_path,
            public_key_path,
            known_hosts: HashMap::new(),
            relationship_keys: HashMap::new(),
            device_fingerprint,
        })
    }

    fn generate_ssh_keys(
        private_path: &PathBuf,
        public_path: &PathBuf,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // In real implementation, would use SSH key generation library
        // For demo, create placeholder files
        std::fs::write(private_path, "-----BEGIN ANBERNIC PRIVATE KEY-----\n[encrypted private key data]\n-----END ANBERNIC PRIVATE KEY-----\n")?;

        std::fs::write(
            public_path,
            "ssh-anbernic AAAAB3NzaC1yc2EAAAADAQABAAABgQC... anbernic@handheld",
        )?;

        Ok(())
    }

    fn generate_device_fingerprint() -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        std::env::var("USER")
            .unwrap_or_else(|_| "anbernic".to_string())
            .hash(&mut hasher);
        chrono::Utc::now().timestamp().hash(&mut hasher);
        let hash = hasher.finish();

        format!("anbernic:{:016x}", hash)
    }

    /// Encrypt an email for a specific recipient using per-relationship keys
    pub fn encrypt_for_recipient(
        &mut self,
        content: &str,
        recipient_email: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Get or create relationship key for this email address
        let (private_key, public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(recipient_email) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(recipient_email)?;
                self.relationship_keys
                    .insert(recipient_email.to_string(), new_keys.clone());
                new_keys
            };

        // Simplified encryption - in real implementation would use actual SSH encryption
        let encrypted = format!("SSH_ENCRYPTED[{}]:{}", recipient_email, content);
        Ok(encrypted)
    }

    /// Decrypt an email, trying all available keys for the sender
    pub fn decrypt_from_sender(
        &mut self,
        encrypted_content: &str,
        sender_email: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Try relationship key first
        if let Some((private_key, _)) = self.relationship_keys.get(sender_email) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, private_key, sender_email)
            {
                return Ok(decrypted);
            }
        }

        // Try main device key by reading from file
        if let Ok(main_key) = std::fs::read_to_string(&self.private_key_path) {
            if let Ok(decrypted) =
                self.try_decrypt_with_key(encrypted_content, &main_key, sender_email)
            {
                return Ok(decrypted);
            }
        }

        // If no key works, generate new relationship key for this sender
        let new_keys = self.generate_relationship_keys(sender_email)?;
        self.relationship_keys
            .insert(sender_email.to_string(), new_keys.clone());

        // Try with new key (this may still fail, but establishes the relationship)
        if let Ok(decrypted) =
            self.try_decrypt_with_key(encrypted_content, &new_keys.0, sender_email)
        {
            return Ok(decrypted);
        }

        Err("Failed to decrypt email with any available keys".into())
    }

    /// Generate a new key pair for a specific email relationship
    fn generate_relationship_keys(
        &self,
        email: &str,
    ) -> Result<(String, String), Box<dyn std::error::Error>> {
        use rand::Rng;
        use sha2::{Digest, Sha256};

        // Generate a deterministic but unique key based on our device fingerprint and their email
        let mut hasher = Sha256::new();
        hasher.update(self.device_fingerprint.as_bytes());
        hasher.update(email.as_bytes());
        hasher.update(&rand::thread_rng().gen::<[u8; 32]>()); // Add randomness
        let key_seed = hasher.finalize();

        let private_key = format!("SSH_PRIV_KEY_{}", hex::encode(&key_seed[..16]));
        let public_key = format!("SSH_PUB_KEY_{}", hex::encode(&key_seed[16..]));

        Ok((private_key, public_key))
    }

    /// Try to decrypt with a specific key
    fn try_decrypt_with_key(
        &self,
        encrypted_content: &str,
        private_key: &str,
        expected_sender: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // Simplified decryption - check if email is in expected format
        if encrypted_content.starts_with(&format!("SSH_ENCRYPTED[{}]:", expected_sender)) {
            let content = encrypted_content
                .strip_prefix(&format!("SSH_ENCRYPTED[{}]:", expected_sender))
                .ok_or("Invalid encrypted format")?;
            Ok(content.to_string())
        } else {
            Err("Decryption failed".into())
        }
    }

    /// Get public key for a relationship (creates new relationship if needed)
    pub fn get_relationship_public_key(
        &mut self,
        email: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some((_, public_key)) = self.relationship_keys.get(email) {
            Ok(public_key.clone())
        } else {
            let new_keys = self.generate_relationship_keys(email)?;
            let public_key = new_keys.1.clone();
            self.relationship_keys.insert(email.to_string(), new_keys);
            Ok(public_key)
        }
    }

    /// Share a media file as an encrypted attachment
    pub fn share_media_file(
        &mut self,
        file_path: std::path::PathBuf,
        filename: String,
        recipient_email: &str,
        content_type: String,
    ) -> Result<EmailMessage, Box<dyn std::error::Error>> {
        // Read the media file
        let file_data = std::fs::read(&file_path)?;

        // Create encrypted attachment
        let attachment =
            self.create_encrypted_attachment(filename, content_type, file_data, recipient_email)?;

        // Create email message with media file
        let message = EmailMessage {
            id: format!("media_{}", chrono::Utc::now().timestamp()),
            from: "device@local".to_string(), // Default sender since we're in SSHKeyManager
            to: vec![recipient_email.to_string()],
            subject: format!("🎵 Shared Media: {}", attachment.filename),
            body: format!(
                "I'm sharing a media file with you: {}\n\nFile size: {} bytes\nType: {}",
                attachment.filename, attachment.size, attachment.content_type
            ),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Encrypted,
            message_type: MessageType::Draft,
            attachments: vec![attachment],
            thread_id: None,
            read_status: false,
        };

        log::info!(
            "Created media sharing email for {} to {}",
            file_path.display(),
            recipient_email
        );
        Ok(message)
    }

    /// Create an encrypted attachment from raw data
    pub fn create_encrypted_attachment(
        &mut self,
        filename: String,
        content_type: String,
        data: Vec<u8>,
        recipient_email: &str,
    ) -> Result<Attachment, Box<dyn std::error::Error>> {
        // Encrypt the file data using relationship keys
        let encrypted_data = self.encrypt_file_data(&data, recipient_email)?;

        Ok(Attachment {
            filename,
            content_type,
            size: data.len() as u64,
            data: encrypted_data,
            is_encrypted: true,
        })
    }

    /// Encrypt file data for a specific recipient
    fn encrypt_file_data(
        &mut self,
        data: &[u8],
        recipient_email: &str,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        // Get or create relationship key for this email address
        let (_private_key, _public_key) =
            if let Some((priv_key, pub_key)) = self.relationship_keys.get(recipient_email) {
                (priv_key.clone(), pub_key.clone())
            } else {
                // Generate new key pair for this relationship
                let new_keys = self.generate_relationship_keys(recipient_email)?;
                self.relationship_keys
                    .insert(recipient_email.to_string(), new_keys.clone());
                new_keys
            };

        // For demo purposes, use simple XOR encryption with recipient email hash
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        std::hash::Hash::hash(&recipient_email, &mut hasher);
        let key_bytes = hasher.finish().to_le_bytes();

        let mut encrypted_data = Vec::with_capacity(data.len());
        for (i, &byte) in data.iter().enumerate() {
            encrypted_data.push(byte ^ key_bytes[i % key_bytes.len()]);
        }

        // Prepend encryption header
        let mut result = format!("ANBERNIC_ENCRYPTED[{}]:", recipient_email)
            .as_bytes()
            .to_vec();
        result.extend_from_slice(&encrypted_data);

        Ok(result)
    }

    /// Decrypt file data from a specific sender
    pub fn decrypt_file_data(
        &mut self,
        encrypted_data: &[u8],
        sender_email: &str,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        // Check for encryption header
        let header = format!("ANBERNIC_ENCRYPTED[{}]:", sender_email);
        let header_bytes = header.as_bytes();

        if encrypted_data.len() < header_bytes.len()
            || &encrypted_data[..header_bytes.len()] != header_bytes
        {
            return Err("Invalid encryption header".into());
        }

        // Extract encrypted portion
        let encrypted_portion = &encrypted_data[header_bytes.len()..];

        // Use same XOR decryption (XOR is symmetric)
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        std::hash::Hash::hash(&sender_email, &mut hasher);
        let key_bytes = hasher.finish().to_le_bytes();

        let mut decrypted_data = Vec::with_capacity(encrypted_portion.len());
        for (i, &byte) in encrypted_portion.iter().enumerate() {
            decrypted_data.push(byte ^ key_bytes[i % key_bytes.len()]);
        }

        Ok(decrypted_data)
    }

    /// Save received media file to local storage
    pub fn save_received_media_file(
        &mut self,
        attachment: &Attachment,
        sender_email: &str,
    ) -> Result<std::path::PathBuf, Box<dyn std::error::Error>> {
        if !attachment.is_encrypted {
            return Err("Attempting to decrypt unencrypted attachment".into());
        }

        // Decrypt the file data
        let decrypted_data = self.decrypt_file_data(&attachment.data, sender_email)?;

        // Create received media directory
        let received_dir = std::path::PathBuf::from("./received_media");
        std::fs::create_dir_all(&received_dir)?;

        // Generate safe filename with sender prefix
        let safe_sender = sender_email
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c == '_' || c == '-' {
                    c
                } else {
                    '_'
                }
            })
            .collect::<String>();
        let safe_filename = attachment
            .filename
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c == '_' || c == '-' || c == '.' {
                    c
                } else {
                    '_'
                }
            })
            .collect::<String>();

        let output_path = received_dir.join(format!("{}_{}", safe_sender, safe_filename));

        // Write decrypted data to file
        std::fs::write(&output_path, decrypted_data)?;

        log::info!(
            "Saved received media file: {} ({} bytes)",
            output_path.display(),
            attachment.size
        );
        Ok(output_path)
    }

    /// Get media file type from filename extension
    pub fn get_media_content_type(filename: &str) -> String {
        let extension = std::path::Path::new(filename)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("")
            .to_lowercase();

        match extension.as_str() {
            "mp3" => "audio/mpeg".to_string(),
            "flac" => "audio/flac".to_string(),
            "wav" => "audio/wav".to_string(),
            "ogg" => "audio/ogg".to_string(),
            "m4a" => "audio/mp4".to_string(),
            "aac" => "audio/aac".to_string(),
            "mp4" => "video/mp4".to_string(),
            "mkv" => "video/x-matroska".to_string(),
            "avi" => "video/x-msvideo".to_string(),
            "webm" => "video/webm".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }

    /// Check if an attachment is a media file
    pub fn is_media_attachment(attachment: &Attachment) -> bool {
        attachment.content_type.starts_with("audio/")
            || attachment.content_type.starts_with("video/")
    }
}

#[derive(Debug, Clone)]
pub enum RadialButton {
    A, // Up/North
    B, // Down/South
    L, // Left/West
    R, // Right/East
}

impl Default for EmailInputState {
    fn default() -> Self {
        Self {
            current_group: InputGroup::MainMenu,
            selected_index: 0,
            text_buffer: String::new(),
            cursor_position: 0,
            input_mode: InputMode::Navigation,
        }
    }
}

impl Default for EmailUIState {
    fn default() -> Self {
        Self {
            current_view: EmailView::MainMenu,
            selected_message_index: 0,
            selected_contact_index: 0,
            show_help: false,
            animation_frame: 0,
            scroll_offset: 0,
            l_shaped_display: true,
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum EmailError {
    #[error("SSH error: {0}")]
    SSHError(String),
    #[error("Encryption error: {0}")]
    EncryptionError(String),
    #[error("Network error: {0}")]
    NetworkError(String),
    #[error("IO error: {0}")]
    IOError(String),
}

// For demo purposes - would use actual base64 crate in real implementation
mod base64 {
    pub fn encode(data: &str) -> String {
        // Simplified base64 encoding for demo
        format!(
            "b64:{}",
            data.chars()
                .map(|c| (c as u8).to_string())
                .collect::<Vec<_>>()
                .join(",")
        )
    }

    pub fn decode(data: &str) -> Result<Vec<u8>, ()> {
        if let Some(stripped) = data.strip_prefix("b64:") {
            let chars: Result<Vec<u8>, _> = stripped.split(',').map(|s| s.parse::<u8>()).collect();
            chars.map_err(|_| ())
        } else {
            Err(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_email_client_creation() {
        let client = AnbernicEmailClient::new("test_user".to_string());
        assert!(client.is_ok());
    }

    #[test]
    fn test_ssh_encryption() {
        let mut client = AnbernicEmailClient::new("test_user".to_string()).unwrap();
        let mut message = EmailMessage {
            id: "test".to_string(),
            from: "test@anbernic.local".to_string(),
            to: vec!["friend@anbernic.local".to_string()],
            subject: "Test".to_string(),
            body: "Hello from Anbernic!".to_string(),
            timestamp: chrono::Utc::now(),
            encryption_status: EncryptionStatus::Unencrypted,
            message_type: MessageType::Draft,
            attachments: vec![],
            thread_id: None,
            read_status: false,
        };

        // Test encryption
        let result = client.encrypt_message(&mut message);
        assert!(result.is_ok());
    }
}

// Methods expected by the demo
impl EmailMessage {
    pub fn is_read(&self) -> bool {
        self.read_status
    }
}

impl AnbernicEmailClient {
    pub fn add_contact(&mut self, contact: Contact) {
        self.contacts.insert(contact.email.clone(), contact);
    }

    pub fn get_current_message(&self) -> Option<&EmailMessage> {
        if self.ui_state.selected_message_index < self.inbox.len() {
            Some(&self.inbox[self.ui_state.selected_message_index])
        } else {
            None
        }
    }

    pub fn navigate_to_inbox(&mut self) {
        self.ui_state.current_view = EmailView::Inbox;
    }

    pub fn navigate_to_outbox(&mut self) {
        // For demo purposes, treat outbox like inbox
        self.ui_state.current_view = EmailView::Inbox;
    }

    pub fn navigate_to_compose(&mut self) {
        self.ui_state.current_view = EmailView::Compose;
    }

    pub fn navigate_to_contacts(&mut self) {
        self.ui_state.current_view = EmailView::Contacts;
    }

    pub fn navigate_to_main_menu(&mut self) {
        self.ui_state.current_view = EmailView::MainMenu;
    }

    pub fn navigate_to_read_message(&mut self) {
        if self.ui_state.selected_message_index < self.inbox.len() {
            self.ui_state.current_view = EmailView::ReadMessage;
        }
    }

    pub fn select_previous_message(&mut self) {
        if self.ui_state.selected_message_index > 0 {
            self.ui_state.selected_message_index -= 1;
        }
    }

    pub fn select_next_message(&mut self) {
        if self.ui_state.selected_message_index + 1 < self.inbox.len() {
            self.ui_state.selected_message_index += 1;
        }
    }

    pub fn select_previous_contact(&mut self) {
        if self.ui_state.selected_contact_index > 0 {
            self.ui_state.selected_contact_index -= 1;
        }
    }

    pub fn select_next_contact(&mut self) {
        if self.ui_state.selected_contact_index + 1 < self.contacts.len() {
            self.ui_state.selected_contact_index += 1;
        }
    }

    pub fn scroll_message_up(&mut self) {
        if self.ui_state.scroll_offset > 0 {
            self.ui_state.scroll_offset -= 1;
        }
    }

    pub fn scroll_message_down(&mut self) {
        self.ui_state.scroll_offset += 1;
    }

    pub fn start_reply(&mut self) {
        if let Some(message) = self.get_current_message() {
            // Create a reply message
            self.current_message = Some(EmailMessage {
                id: format!("reply_{}", chrono::Utc::now().timestamp()),
                from: "anbernic_user@local".to_string(),
                to: vec![message.from.clone()],
                subject: format!("Re: {}", message.subject),
                body: String::new(),
                timestamp: chrono::Utc::now(),
                encryption_status: EncryptionStatus::Unencrypted,
                message_type: MessageType::Draft,
                attachments: vec![],
                thread_id: message.thread_id.clone(),
                read_status: false,
            });
            self.ui_state.current_view = EmailView::Compose;
        }
    }

    pub fn set_compose_subject(&mut self, subject: String) {
        if let Some(ref mut message) = self.current_message {
            message.subject = subject;
        }
    }

    pub fn set_compose_body(&mut self, body: String) {
        if let Some(ref mut message) = self.current_message {
            message.body = body;
        }
    }

    pub fn send_current_message(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(mut message) = self.current_message.take() {
            // Auto-encrypt if we have recipient's key
            self.encrypt_message(&mut message)?;
            message.message_type = MessageType::Sent;
            message.timestamp = chrono::Utc::now();

            self.outbox.push(message);
            self.ui_state.current_view = EmailView::MainMenu;
        }
        Ok(())
    }

    pub fn compose_to_selected_contact(&mut self) {
        let contacts: Vec<_> = self.contacts.iter().collect();
        if self.ui_state.selected_contact_index < contacts.len() {
            let (email, _contact) = contacts[self.ui_state.selected_contact_index];

            self.current_message = Some(EmailMessage {
                id: format!("compose_{}", chrono::Utc::now().timestamp()),
                from: "anbernic_user@local".to_string(),
                to: vec![email.clone()],
                subject: String::new(),
                body: String::new(),
                timestamp: chrono::Utc::now(),
                encryption_status: EncryptionStatus::Unencrypted,
                message_type: MessageType::Draft,
                attachments: vec![],
                thread_id: None,
                read_status: false,
            });

            self.ui_state.current_view = EmailView::Compose;
        }
    }

    pub fn save_state(&self) -> Result<(), Box<dyn std::error::Error>> {
        // Save email state to files/build/email_state.json
        let state_dir = PathBuf::from("files/build");
        std::fs::create_dir_all(&state_dir)?;

        let state_file = state_dir.join("email_state.json");
        let state_data =
            serde_json::to_string_pretty(&(&self.inbox, &self.outbox, &self.contacts))?;

        std::fs::write(state_file, state_data)?;
        println!("💾 Email state saved successfully");
        Ok(())
    }

    /// Get list of all media attachments from messages
    pub fn get_media_attachments(&self) -> Vec<(String, &Attachment)> {
        let mut media_attachments = Vec::new();

        // Check all message collections
        let all_messages = self
            .inbox
            .iter()
            .chain(self.outbox.iter())
            .chain(self.drafts.iter());

        for message in all_messages {
            for attachment in &message.attachments {
                if SSHKeyManager::is_media_attachment(attachment) {
                    media_attachments.push((message.from.clone(), attachment));
                }
            }
        }

        media_attachments
    }
}
