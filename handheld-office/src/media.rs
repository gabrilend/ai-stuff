use crate::p2p_mesh::{DeviceType, P2PIntegration, P2PMeshManager, PeerDevice, SharedFile};
use rodio::{Decoder, OutputStream, OutputStreamHandle, Sink};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::time::Duration;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use tokio::process::Command as TokioCommand;

/// Button input for radial navigation
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum RadialButton {
    A, // North/Up
    B, // South/Down
    L, // West/Left
    R, // East/Right
}

/// Media file types supported by the player
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum MediaType {
    Audio,
    Video,
    Unknown,
}

/// Media format information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaFormat {
    pub extension: String,
    pub media_type: MediaType,
    pub codec: Option<String>,
    pub supported: bool,
}

/// Individual media file information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaFile {
    pub path: PathBuf,
    pub filename: String,
    pub format: MediaFormat,
    pub duration: Option<Duration>,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub file_size: u64,
}

/// Playlist containing media files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Playlist {
    pub name: String,
    pub files: Vec<MediaFile>,
    pub current_index: usize,
    pub shuffle: bool,
    pub repeat: bool,
}

/// Media library management
#[derive(Debug)]
pub struct MediaLibrary {
    pub media_directories: Vec<PathBuf>,
    pub audio_files: Vec<MediaFile>,
    pub video_files: Vec<MediaFile>,
    pub playlists: HashMap<String, Playlist>,
    pub recent_files: VecDeque<MediaFile>,
    pub file_cache: HashMap<PathBuf, MediaFile>,
}

/// Playback state information
#[derive(Debug, Clone, PartialEq)]
pub enum PlaybackState {
    Stopped,
    Playing,
    Paused,
    Buffering,
    Error(String),
}

/// Current playback information
#[derive(Debug)]
pub struct PlaybackInfo {
    pub state: PlaybackState,
    pub current_file: Option<MediaFile>,
    pub position: Duration,
    pub duration: Option<Duration>,
    pub volume: f32,
    pub muted: bool,
}

/// UI navigation states
#[derive(Debug, Clone, PartialEq)]
pub enum MediaUIState {
    MainMenu,
    AudioLibrary,
    VideoLibrary,
    Playlists,
    NowPlaying,
    Settings,
    FileBrowser,
    P2PBrowser,
    P2PSearch,
    P2PTransfers,
}

/// Input handling states
#[derive(Debug, Clone, PartialEq)]
pub enum MediaInputMode {
    Navigation,
    VolumeControl,
    SeekControl,
    PlaylistEdit,
}

/// Video playback information
#[derive(Debug)]
pub struct VideoInfo {
    pub width: u32,
    pub height: u32,
    pub fps: f32,
    pub codec: String,
    pub bitrate: Option<u64>,
}

/// Video player state
#[derive(Debug, Clone, PartialEq)]
pub enum VideoPlayer {
    None,
    FFplay(Option<u32>),    // Process ID if running
    MPV(Option<u32>),       // Process ID if running
    ASCII(ASCIIVideoState), // ASCII art video for handheld devices
}

/// ASCII video rendering for low-resolution displays
#[derive(Debug, Clone, PartialEq)]
pub struct ASCIIVideoState {
    pub current_frame: Vec<String>,
    pub frame_rate: f32,
    pub width: usize,
    pub height: usize,
    pub frame_count: u64,
}

/// Main media player structure
pub struct AnbernicMediaPlayer {
    // Core components
    pub media_library: MediaLibrary,
    pub playback_info: PlaybackInfo,

    // Audio system
    pub audio_stream: Option<OutputStream>,
    pub audio_handle: Option<OutputStreamHandle>,
    pub audio_sink: Option<Arc<Sink>>,

    // Video system
    pub video_player: VideoPlayer,
    pub video_info: Option<VideoInfo>,
    pub ascii_mode: bool,

    // P2P mesh networking
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_files_cache: Vec<SharedFile>,
    pub mesh_peers_cache: Vec<PeerDevice>,

    // Navigation and UI
    pub ui_state: MediaUIState,
    pub input_mode: MediaInputMode,
    pub selected_index: usize,
    pub menu_stack: Vec<MediaUIState>,

    // Playback queue
    pub current_playlist: Option<Playlist>,
    pub play_queue: VecDeque<MediaFile>,

    // Settings
    pub auto_scan_libraries: bool,
    pub default_volume: f32,
    pub video_output_enabled: bool,
}

/// Type alias for documentation compatibility
pub type MediaPlayer = AnbernicMediaPlayer;

impl Default for MediaFormat {
    fn default() -> Self {
        Self {
            extension: String::new(),
            media_type: MediaType::Unknown,
            codec: None,
            supported: false,
        }
    }
}

impl MediaLibrary {
    pub fn new() -> Self {
        Self {
            media_directories: vec![
                PathBuf::from("/media"),
                PathBuf::from("/mnt"),
                PathBuf::from("./music"),
                PathBuf::from("./videos"),
            ],
            audio_files: Vec::new(),
            video_files: Vec::new(),
            playlists: HashMap::new(),
            recent_files: VecDeque::with_capacity(20),
            file_cache: HashMap::new(),
        }
    }

    /// Scan directories for media files
    pub async fn scan_media_directories(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.audio_files.clear();
        self.video_files.clear();

        for dir in &self.media_directories.clone() {
            if dir.exists() {
                self.scan_directory_recursive(dir).await?;
            }
        }

        log::info!(
            "Media scan complete: {} audio, {} video files",
            self.audio_files.len(),
            self.video_files.len()
        );
        Ok(())
    }

    fn scan_directory_recursive<'a>(
        &'a mut self,
        dir: &'a Path,
    ) -> std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<(), Box<dyn std::error::Error>>> + 'a>,
    > {
        Box::pin(async move {
            let mut entries = tokio::fs::read_dir(dir).await?;

            while let Some(entry) = entries.next_entry().await? {
                let path = entry.path();

                if path.is_dir() {
                    // Recursively scan subdirectories
                    if let Err(e) = self.scan_directory_recursive(&path).await {
                        log::warn!("Failed to scan directory {:?}: {}", path, e);
                    }
                } else if path.is_file() {
                    if let Some(media_file) = self.analyze_media_file(&path).await? {
                        // Cache the file
                        self.file_cache.insert(path.clone(), media_file.clone());

                        // Add to appropriate collection
                        match media_file.format.media_type {
                            MediaType::Audio => self.audio_files.push(media_file),
                            MediaType::Video => self.video_files.push(media_file),
                            MediaType::Unknown => {} // Skip unknown files
                        }
                    }
                }
            }

            Ok(())
        })
    }

    async fn analyze_media_file(
        &self,
        path: &Path,
    ) -> Result<Option<MediaFile>, Box<dyn std::error::Error>> {
        let extension = path
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("")
            .to_lowercase();

        let format = Self::get_media_format(&extension);

        if !format.supported {
            return Ok(None);
        }

        let metadata = tokio::fs::metadata(path).await?;
        let filename = path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("Unknown")
            .to_string();

        // Try to extract metadata for audio files
        let (title, artist, album, duration) = if format.media_type == MediaType::Audio {
            self.extract_audio_metadata(path).await
        } else {
            (None, None, None, None)
        };

        Ok(Some(MediaFile {
            path: path.to_path_buf(),
            filename,
            format,
            duration,
            title,
            artist,
            album,
            file_size: metadata.len(),
        }))
    }

    async fn extract_audio_metadata(
        &self,
        path: &Path,
    ) -> (
        Option<String>,
        Option<String>,
        Option<String>,
        Option<Duration>,
    ) {
        // Try to use Symphonia to extract metadata
        match std::fs::File::open(path) {
            Ok(file) => {
                let mss = MediaSourceStream::new(Box::new(file), Default::default());
                let hint = Hint::new();
                let format_opts = FormatOptions::default();
                let metadata_opts = MetadataOptions::default();

                match symphonia::default::get_probe().format(
                    &hint,
                    mss,
                    &format_opts,
                    &metadata_opts,
                ) {
                    Ok(mut probed) => {
                        let mut title = None;
                        let mut artist = None;
                        let mut album = None;
                        let mut duration = None;

                        // Extract metadata
                        if let Some(metadata) = probed.metadata.get() {
                            if let Some(current) = metadata.current() {
                                for tag in current.tags() {
                                    match tag.key.as_str() {
                                        "TITLE" => title = Some(tag.value.to_string()),
                                        "ARTIST" => artist = Some(tag.value.to_string()),
                                        "ALBUM" => album = Some(tag.value.to_string()),
                                        _ => {}
                                    }
                                }
                            }
                        }

                        // Try to get duration from format
                        if let Some(track) = probed.format.default_track() {
                            if let Some(time_base) = track.codec_params.time_base {
                                if let Some(n_frames) = track.codec_params.n_frames {
                                    let seconds = n_frames as f64 * time_base.numer as f64
                                        / time_base.denom as f64;
                                    duration = Some(Duration::from_secs_f64(seconds));
                                }
                            }
                        }

                        (title, artist, album, duration)
                    }
                    Err(_) => (None, None, None, None),
                }
            }
            Err(_) => (None, None, None, None),
        }
    }

    fn get_media_format(extension: &str) -> MediaFormat {
        match extension {
            // Audio formats
            "mp3" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Audio,
                codec: Some("MP3".to_string()),
                supported: true,
            },
            "flac" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Audio,
                codec: Some("FLAC".to_string()),
                supported: true,
            },
            "wav" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Audio,
                codec: Some("PCM".to_string()),
                supported: true,
            },
            "ogg" | "oga" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Audio,
                codec: Some("Vorbis".to_string()),
                supported: true,
            },
            "m4a" | "aac" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Audio,
                codec: Some("AAC".to_string()),
                supported: true,
            },

            // Video formats - now supported!
            "mp4" | "m4v" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Video,
                codec: Some("H.264".to_string()),
                supported: true,
            },
            "mkv" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Video,
                codec: Some("Matroska".to_string()),
                supported: true,
            },
            "avi" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Video,
                codec: Some("AVI".to_string()),
                supported: true,
            },
            "webm" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Video,
                codec: Some("VP8/VP9".to_string()),
                supported: true,
            },
            "mov" => MediaFormat {
                extension: extension.to_string(),
                media_type: MediaType::Video,
                codec: Some("QuickTime".to_string()),
                supported: true,
            },

            _ => MediaFormat::default(),
        }
    }

    /// Create a new playlist
    pub fn create_playlist(&mut self, name: String, files: Vec<MediaFile>) -> Result<(), String> {
        if self.playlists.contains_key(&name) {
            return Err("Playlist already exists".to_string());
        }

        let playlist = Playlist {
            name: name.clone(),
            files,
            current_index: 0,
            shuffle: false,
            repeat: false,
        };

        self.playlists.insert(name, playlist);
        Ok(())
    }

    /// Add file to recent files list
    pub fn add_to_recent(&mut self, file: MediaFile) {
        // Remove if already exists
        self.recent_files.retain(|f| f.path != file.path);

        // Add to front
        self.recent_files.push_front(file);

        // Keep only last 20 files
        while self.recent_files.len() > 20 {
            self.recent_files.pop_back();
        }
    }
}

impl AnbernicMediaPlayer {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        // Initialize audio system
        let (stream, handle) = OutputStream::try_default()?;
        let sink = Sink::try_new(&handle)?;

        Ok(Self {
            media_library: MediaLibrary::new(),
            playback_info: PlaybackInfo {
                state: PlaybackState::Stopped,
                current_file: None,
                position: Duration::ZERO,
                duration: None,
                volume: 1.0,
                muted: false,
            },
            audio_stream: Some(stream),
            audio_handle: Some(handle),
            audio_sink: Some(Arc::new(sink)),
            video_player: VideoPlayer::None,
            video_info: None,
            ascii_mode: true, // Default to ASCII mode for handheld devices
            p2p_manager: None,
            p2p_enabled: true,
            shared_files_cache: Vec::new(),
            mesh_peers_cache: Vec::new(),
            ui_state: MediaUIState::MainMenu,
            input_mode: MediaInputMode::Navigation,
            selected_index: 0,
            menu_stack: Vec::new(),
            current_playlist: None,
            play_queue: VecDeque::new(),
            auto_scan_libraries: true,
            default_volume: 0.8,
            video_output_enabled: true,
        })
    }

    /// Enable P2P mesh networking integration
    pub fn enable_p2p(&mut self, p2p_manager: P2PMeshManager) {
        self.p2p_manager = Some(p2p_manager);
        self.p2p_enabled = true;
        log::info!("P2P integration enabled for media player");
    }

    /// Disable P2P mesh networking
    pub fn disable_p2p(&mut self) {
        self.p2p_manager = None;
        self.p2p_enabled = false;
        self.shared_files_cache.clear();
        self.mesh_peers_cache.clear();
        log::info!("P2P integration disabled for media player");
    }

    /// Initialize the media player
    pub async fn initialize(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        log::info!("Initializing Anbernic Media Player...");

        if self.auto_scan_libraries {
            self.media_library.scan_media_directories().await?;
        }

        self.playback_info.volume = self.default_volume;
        if let Some(sink) = &self.audio_sink {
            sink.set_volume(self.default_volume);
        }

        // Initialize P2P mesh if enabled
        if self.p2p_enabled {
            if let Err(e) = self.initialize_p2p().await {
                log::warn!("P2P initialization failed: {}", e);
                self.p2p_enabled = false;
            }
        }

        log::info!("Media player initialized successfully");
        Ok(())
    }

    /// Initialize P2P mesh networking
    async fn initialize_p2p(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let device_name = format!("Anbernic-Media-{}", std::process::id());
        let device_type = DeviceType::Anbernic("Media Player".to_string());

        let mut p2p_manager = P2PMeshManager::new(device_name, device_type)?;
        p2p_manager.start().await?;

        self.p2p_manager = Some(p2p_manager);
        log::info!("P2P mesh networking initialized for media player");
        Ok(())
    }

    /// Share a media file via P2P
    pub async fn share_file_p2p(
        &mut self,
        file_path: PathBuf,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let tags = vec!["media".to_string(), "anbernic".to_string()];
            let description = Some("Shared from Anbernic Media Player".to_string());

            let file_id = p2p_manager.share_file(file_path, description, tags).await?;
            self.refresh_p2p_cache().await?;
            Ok(file_id)
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Request a file from a peer
    pub async fn request_file_from_peer(
        &mut self,
        file_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            p2p_manager.request_file(file_id, peer_id).await?;
            Ok(())
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Search for media files across the mesh
    pub async fn search_mesh_files(
        &mut self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let file_types = vec![
                "mp3".to_string(),
                "mp4".to_string(),
                "flac".to_string(),
                "avi".to_string(),
            ];
            let results = p2p_manager.search_files(query, file_types).await?;
            Ok(results)
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Refresh P2P cache data
    async fn refresh_p2p_cache(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            self.shared_files_cache = p2p_manager.get_available_files().await;
            self.mesh_peers_cache = p2p_manager.get_peers().await;
            Ok(())
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Handle radial button input
    pub async fn handle_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.input_mode {
            MediaInputMode::Navigation => self.handle_navigation_input(button).await?,
            MediaInputMode::VolumeControl => self.handle_volume_input(button)?,
            MediaInputMode::SeekControl => self.handle_seek_input(button)?,
            MediaInputMode::PlaylistEdit => self.handle_playlist_edit_input(button)?,
        }
        Ok(())
    }

    async fn handle_navigation_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.ui_state {
            MediaUIState::MainMenu => {
                match button {
                    RadialButton::A => {
                        // Move up in menu
                        if self.selected_index > 0 {
                            self.selected_index -= 1;
                        }
                    }
                    RadialButton::B => {
                        // Move down in menu
                        let menu_items = self.get_main_menu_items();
                        if self.selected_index < menu_items.len().saturating_sub(1) {
                            self.selected_index += 1;
                        }
                    }
                    RadialButton::R => {
                        // Select menu item
                        match self.selected_index {
                            0 => self.transition_to_state(MediaUIState::AudioLibrary),
                            1 => self.transition_to_state(MediaUIState::VideoLibrary),
                            2 => self.transition_to_state(MediaUIState::Playlists),
                            3 => self.transition_to_state(MediaUIState::NowPlaying),
                            4 => self.transition_to_state(MediaUIState::Settings),
                            5 => self.transition_to_state(MediaUIState::FileBrowser),
                            _ => {}
                        }
                    }
                    RadialButton::L => {
                        // Back/Exit - handled by menu stack
                        self.go_back();
                    }
                }
            }

            MediaUIState::AudioLibrary => {
                match button {
                    RadialButton::A => {
                        if self.selected_index > 0 {
                            self.selected_index -= 1;
                        }
                    }
                    RadialButton::B => {
                        if self.selected_index
                            < self.media_library.audio_files.len().saturating_sub(1)
                        {
                            self.selected_index += 1;
                        }
                    }
                    RadialButton::R => {
                        // Play selected audio file
                        if let Some(file) = self.media_library.audio_files.get(self.selected_index)
                        {
                            self.play_media_file(file.clone()).await?;
                            self.transition_to_state(MediaUIState::NowPlaying);
                        }
                    }
                    RadialButton::L => {
                        self.go_back();
                    }
                }
            }

            MediaUIState::NowPlaying => {
                match button {
                    RadialButton::A => {
                        // Previous track
                        self.previous_track().await?;
                    }
                    RadialButton::B => {
                        // Next track
                        self.next_track().await?;
                    }
                    RadialButton::R => {
                        // Play/Pause toggle
                        self.toggle_playback()?;
                    }
                    RadialButton::L => {
                        // Back to previous menu
                        self.go_back();
                    }
                }
            }

            // Add other UI state handlers...
            _ => match button {
                RadialButton::L => self.go_back(),
                _ => {}
            },
        }
        Ok(())
    }

    fn handle_volume_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                // Volume up
                self.adjust_volume(0.1)?;
            }
            RadialButton::B => {
                // Volume down
                self.adjust_volume(-0.1)?;
            }
            RadialButton::R => {
                // Toggle mute
                self.toggle_mute()?;
            }
            RadialButton::L => {
                // Exit volume control mode
                self.input_mode = MediaInputMode::Navigation;
            }
        }
        Ok(())
    }

    fn handle_seek_input(
        &mut self,
        button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            RadialButton::A => {
                // Seek backward
                self.seek_relative(Duration::from_secs(10), false)?;
            }
            RadialButton::B => {
                // Seek forward
                self.seek_relative(Duration::from_secs(10), true)?;
            }
            RadialButton::L => {
                // Exit seek mode
                self.input_mode = MediaInputMode::Navigation;
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_playlist_edit_input(
        &mut self,
        _button: RadialButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // TODO: Implement playlist editing
        self.input_mode = MediaInputMode::Navigation;
        Ok(())
    }

    /// Play a media file
    pub async fn play_media_file(
        &mut self,
        file: MediaFile,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match file.format.media_type {
            MediaType::Audio => self.play_audio_file(file).await,
            MediaType::Video => self.play_video_file(file).await,
            MediaType::Unknown => Err("Unsupported media type".into()),
        }
    }

    async fn play_audio_file(&mut self, file: MediaFile) -> Result<(), Box<dyn std::error::Error>> {
        // Stop current playback
        if let Some(sink) = &self.audio_sink {
            sink.stop();
        }

        // Create new sink
        if let Some(handle) = &self.audio_handle {
            let sink = Sink::try_new(handle)?;

            // Open the audio file
            let file_handle = std::fs::File::open(&file.path)?;
            let source = Decoder::new(file_handle)?;

            sink.append(source);
            sink.set_volume(self.playback_info.volume);

            if !self.playback_info.muted {
                sink.play();
            } else {
                sink.pause();
            }

            self.audio_sink = Some(Arc::new(sink));
        }

        // Update playback info
        self.playback_info.current_file = Some(file.clone());
        self.playback_info.state = PlaybackState::Playing;
        self.playback_info.position = Duration::ZERO;
        self.playback_info.duration = file.duration;

        // Add to recent files
        self.media_library.add_to_recent(file);

        log::info!(
            "Now playing: {}",
            self.playback_info.current_file.as_ref().unwrap().filename
        );
        Ok(())
    }

    async fn play_video_file(&mut self, file: MediaFile) -> Result<(), Box<dyn std::error::Error>> {
        // Stop any current video playback
        self.stop_video_playback().await?;

        if self.ascii_mode {
            // ASCII art video for handheld devices
            self.play_ascii_video(file.clone()).await?;
        } else {
            // Try external players for full video
            if self.try_mpv_player(&file.path).await.is_ok() {
                self.video_player = VideoPlayer::MPV(None);
            } else if self.try_ffplay_player(&file.path).await.is_ok() {
                self.video_player = VideoPlayer::FFplay(None);
            } else {
                // Fallback to ASCII mode
                self.ascii_mode = true;
                self.play_ascii_video(file.clone()).await?;
            }
        }

        // Update playback info
        self.playback_info.current_file = Some(file.clone());
        self.playback_info.state = PlaybackState::Playing;
        self.playback_info.position = Duration::ZERO;
        self.playback_info.duration = file.duration;

        // Add to recent files
        self.media_library.add_to_recent(file);

        log::info!(
            "Now playing video: {}",
            self.playback_info.current_file.as_ref().unwrap().filename
        );
        Ok(())
    }

    async fn stop_video_playback(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        match &self.video_player {
            VideoPlayer::FFplay(Some(pid)) | VideoPlayer::MPV(Some(pid)) => {
                // Kill the external player process
                Command::new("kill").arg(pid.to_string()).output()?;
            }
            _ => {}
        }
        self.video_player = VideoPlayer::None;
        self.video_info = None;
        Ok(())
    }

    async fn play_ascii_video(
        &mut self,
        file: MediaFile,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Generate ASCII frames from video using ffmpeg
        let ascii_state = self.generate_ascii_frames(&file.path).await?;
        self.video_player = VideoPlayer::ASCII(ascii_state);
        Ok(())
    }

    async fn generate_ascii_frames(
        &self,
        video_path: &Path,
    ) -> Result<ASCIIVideoState, Box<dyn std::error::Error>> {
        // Use ffmpeg to extract frames and convert to ASCII
        let output = TokioCommand::new("ffmpeg")
            .args([
                "-i",
                video_path.to_str().unwrap(),
                "-vf",
                "scale=80:24,format=gray", // Scale to handheld resolution
                "-f",
                "rawvideo",
                "-pix_fmt",
                "gray",
                "-",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .output()
            .await?;

        if !output.status.success() {
            return Err("Failed to process video with ffmpeg".into());
        }

        // Convert raw video data to ASCII
        let frame_data = output.stdout;
        let frame_size = 80 * 24; // width * height
        let frame_count = frame_data.len() / frame_size;

        let mut ascii_frames = Vec::new();

        for i in 0..frame_count {
            let start = i * frame_size;
            let end = start + frame_size;
            let frame_bytes = &frame_data[start..end];

            let ascii_frame = self.bytes_to_ascii_frame(frame_bytes, 80, 24);
            ascii_frames.push(ascii_frame);
        }

        Ok(ASCIIVideoState {
            current_frame: if ascii_frames.is_empty() {
                vec!["No video data".to_string()]
            } else {
                ascii_frames[0].clone()
            },
            frame_rate: 10.0, // Reduced frame rate for handhelds
            width: 80,
            height: 24,
            frame_count: frame_count as u64,
        })
    }

    fn bytes_to_ascii_frame(&self, bytes: &[u8], width: usize, height: usize) -> Vec<String> {
        let ascii_chars = " .:-=+*#%@";
        let mut frame = Vec::new();

        for y in 0..height {
            let mut line = String::new();
            for x in 0..width {
                let index = y * width + x;
                if index < bytes.len() {
                    let brightness = bytes[index] as usize;
                    let char_index = (brightness * (ascii_chars.len() - 1)) / 255;
                    line.push(ascii_chars.chars().nth(char_index).unwrap_or(' '));
                } else {
                    line.push(' ');
                }
            }
            frame.push(line);
        }

        frame
    }

    async fn try_mpv_player(&self, video_path: &Path) -> Result<u32, Box<dyn std::error::Error>> {
        let child = TokioCommand::new("mpv")
            .args([
                "--no-audio", // We handle audio separately
                "--loop=no",
                "--really-quiet",
                video_path.to_str().unwrap(),
            ])
            .spawn()?;

        Ok(child.id().unwrap_or(0))
    }

    async fn try_ffplay_player(
        &self,
        video_path: &Path,
    ) -> Result<u32, Box<dyn std::error::Error>> {
        let child = TokioCommand::new("ffplay")
            .args([
                "-nodisp", // No display for handheld
                "-an",     // No audio
                "-autoexit",
                video_path.to_str().unwrap(),
            ])
            .spawn()?;

        Ok(child.id().unwrap_or(0))
    }

    /// Toggle play/pause
    pub fn toggle_playback(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(sink) = &self.audio_sink {
            match self.playback_info.state {
                PlaybackState::Playing => {
                    sink.pause();
                    self.playback_info.state = PlaybackState::Paused;
                }
                PlaybackState::Paused => {
                    sink.play();
                    self.playback_info.state = PlaybackState::Playing;
                }
                _ => {}
            }
        }
        Ok(())
    }

    /// Adjust volume
    pub fn adjust_volume(&mut self, delta: f32) -> Result<(), Box<dyn std::error::Error>> {
        self.playback_info.volume = (self.playback_info.volume + delta).clamp(0.0, 1.0);

        if let Some(sink) = &self.audio_sink {
            sink.set_volume(self.playback_info.volume);
        }

        Ok(())
    }

    /// Toggle mute
    pub fn toggle_mute(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.playback_info.muted = !self.playback_info.muted;

        if let Some(sink) = &self.audio_sink {
            if self.playback_info.muted {
                sink.pause();
            } else {
                sink.play();
            }
        }

        Ok(())
    }

    /// Seek to relative position
    pub fn seek_relative(
        &mut self,
        duration: Duration,
        forward: bool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Note: rodio doesn't support seeking directly
        // This is a placeholder for future implementation with a different audio library
        // or a custom implementation that tracks position

        if forward {
            self.playback_info.position += duration;
        } else {
            self.playback_info.position = self.playback_info.position.saturating_sub(duration);
        }

        Ok(())
    }

    /// Play next track
    pub async fn next_track(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(playlist) = &mut self.current_playlist {
            if playlist.current_index < playlist.files.len().saturating_sub(1) {
                playlist.current_index += 1;
                let next_file = playlist.files[playlist.current_index].clone();
                self.play_media_file(next_file).await?;
            }
        }
        Ok(())
    }

    /// Play previous track
    pub async fn previous_track(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(playlist) = &mut self.current_playlist {
            if playlist.current_index > 0 {
                playlist.current_index -= 1;
                let prev_file = playlist.files[playlist.current_index].clone();
                self.play_media_file(prev_file).await?;
            }
        }
        Ok(())
    }

    /// Navigation helpers
    fn transition_to_state(&mut self, new_state: MediaUIState) {
        self.menu_stack.push(self.ui_state.clone());
        self.ui_state = new_state;
        self.selected_index = 0;
    }

    fn go_back(&mut self) {
        if let Some(previous_state) = self.menu_stack.pop() {
            self.ui_state = previous_state;
            self.selected_index = 0;
        }
    }

    fn get_main_menu_items(&self) -> Vec<&str> {
        if self.p2p_enabled {
            vec![
                "🎵 Audio Library",
                "🎬 Video Library",
                "📋 Playlists",
                "▶️ Now Playing",
                "🌐 P2P Browser",
                "🔍 P2P Search",
                "📤 P2P Transfers",
                "⚙️ Settings",
                "📁 File Browser",
            ]
        } else {
            vec![
                "🎵 Audio Library",
                "🎬 Video Library",
                "📋 Playlists",
                "▶️ Now Playing",
                "⚙️ Settings",
                "📁 File Browser",
            ]
        }
    }

    /// Get current UI display information
    pub fn render_display(&self) -> String {
        match self.ui_state {
            MediaUIState::MainMenu => self.render_main_menu(),
            MediaUIState::AudioLibrary => self.render_audio_library(),
            MediaUIState::NowPlaying => self.render_now_playing(),
            _ => format!("Media Player - {:?}", self.ui_state),
        }
    }

    fn render_main_menu(&self) -> String {
        let menu_items = self.get_main_menu_items();
        let mut display = String::from("🎮 ANBERNIC MEDIA PLAYER 🎮\n\n");

        for (i, item) in menu_items.iter().enumerate() {
            if i == self.selected_index {
                display.push_str(&format!("► {}\n", item));
            } else {
                display.push_str(&format!("  {}\n", item));
            }
        }

        display.push_str("\nA/B: Navigate  R: Select  L: Back");
        display
    }

    fn render_audio_library(&self) -> String {
        let mut display = String::from("🎵 AUDIO LIBRARY 🎵\n\n");

        if self.media_library.audio_files.is_empty() {
            display.push_str("No audio files found.\nScan media directories in Settings.");
        } else {
            let start = self.selected_index.saturating_sub(5);
            let end = (start + 10).min(self.media_library.audio_files.len());

            for (i, file) in self.media_library.audio_files[start..end]
                .iter()
                .enumerate()
            {
                let actual_index = start + i;
                let prefix = if actual_index == self.selected_index {
                    "► "
                } else {
                    "  "
                };

                let display_name = file
                    .title
                    .as_ref()
                    .map(|t| {
                        if let Some(artist) = &file.artist {
                            format!("{} - {}", artist, t)
                        } else {
                            t.clone()
                        }
                    })
                    .unwrap_or_else(|| file.filename.clone());

                display.push_str(&format!("{}{}\n", prefix, display_name));
            }

            display.push_str(&format!(
                "\n{}/{} files",
                self.selected_index + 1,
                self.media_library.audio_files.len()
            ));
        }

        display.push_str("\nA/B: Navigate  R: Play  L: Back");
        display
    }

    fn render_now_playing(&self) -> String {
        let mut display = String::from("▶️ NOW PLAYING ▶️\n\n");

        if let Some(file) = &self.playback_info.current_file {
            // Display current track info
            if let Some(title) = &file.title {
                display.push_str(&format!("Title: {}\n", title));
            }
            if let Some(artist) = &file.artist {
                display.push_str(&format!("Artist: {}\n", artist));
            }
            if let Some(album) = &file.album {
                display.push_str(&format!("Album: {}\n", album));
            }

            display.push_str(&format!("File: {}\n", file.filename));
            display.push_str(&format!(
                "Format: {}\n",
                file.format.extension.to_uppercase()
            ));

            // Playback status
            let status_icon = match self.playback_info.state {
                PlaybackState::Playing => "▶️",
                PlaybackState::Paused => "⏸️",
                PlaybackState::Stopped => "⏹️",
                PlaybackState::Buffering => "⏳",
                PlaybackState::Error(_) => "❌",
            };

            display.push_str(&format!(
                "\nStatus: {} {:?}\n",
                status_icon, self.playback_info.state
            ));

            // Volume and position
            let volume_percent = (self.playback_info.volume * 100.0) as u8;
            let mute_indicator = if self.playback_info.muted {
                " (MUTED)"
            } else {
                ""
            };
            display.push_str(&format!("Volume: {}%{}\n", volume_percent, mute_indicator));

            // Time display
            let pos_secs = self.playback_info.position.as_secs();
            let pos_mins = pos_secs / 60;
            let pos_secs = pos_secs % 60;

            if let Some(duration) = self.playback_info.duration {
                let dur_secs = duration.as_secs();
                let dur_mins = dur_secs / 60;
                let dur_secs = dur_secs % 60;
                display.push_str(&format!(
                    "Time: {:02}:{:02} / {:02}:{:02}\n",
                    pos_mins, pos_secs, dur_mins, dur_secs
                ));
            } else {
                display.push_str(&format!("Time: {:02}:{:02}\n", pos_mins, pos_secs));
            }
        } else {
            display.push_str("No media currently playing.\n");
        }

        display.push_str("\nA: Previous  B: Next  R: Play/Pause  L: Back");
        display
    }

    /// Export media file for sharing (returns file data for encryption/transmission)
    pub async fn export_media_file(
        &self,
        file: &MediaFile,
    ) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
        let data = tokio::fs::read(&file.path).await?;
        log::info!(
            "Exported media file: {} ({} bytes)",
            file.filename,
            data.len()
        );
        Ok(data)
    }

    /// Import media file from shared data
    pub async fn import_media_file(
        &mut self,
        filename: String,
        data: Vec<u8>,
        sender: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create received files directory
        let received_dir = PathBuf::from("./received_media");
        tokio::fs::create_dir_all(&received_dir).await?;

        // Save file with sender prefix
        let safe_filename = format!("{}_{}", sender.replace(['/', '\\', ':'], "_"), filename);
        let file_path = received_dir.join(&safe_filename);

        tokio::fs::write(&file_path, data).await?;

        // Analyze the imported file
        if let Some(media_file) = self.media_library.analyze_media_file(&file_path).await? {
            // Add to appropriate library
            match media_file.format.media_type {
                MediaType::Audio => {
                    self.media_library.audio_files.push(media_file.clone());
                    self.media_library.add_to_recent(media_file);
                }
                MediaType::Video => {
                    self.media_library.video_files.push(media_file);
                }
                MediaType::Unknown => {}
            }
        }

        log::info!("Imported media file from {}: {}", sender, safe_filename);
        Ok(())
    }
}

impl Default for AnbernicMediaPlayer {
    fn default() -> Self {
        Self::new().expect("Failed to create default media player")
    }
}

impl P2PIntegration for AnbernicMediaPlayer {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager
            .as_ref()
            .expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let tags = vec!["media".to_string()];
            p2p_manager.share_file(file_path, None, tags).await
        } else {
            Err("P2P not initialized".into())
        }
    }
}
