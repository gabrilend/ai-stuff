use crate::p2p_mesh::{DeviceType, P2PIntegration, P2PMeshManager, PeerDevice, SharedFile};
use chrono;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Vector-based paint tool optimized for Game Boy Advance constraints
/// Stores points/strokes instead of pixel data for memory efficiency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorPaintCanvas {
    pub strokes: Vec<Stroke>,
    pub canvas_width: u16,
    pub canvas_height: u16,
    pub current_stroke: Option<Stroke>,
    pub cursor: Point,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Stroke {
    pub points: Vec<Point>,
    pub color: u8,     // 0-15 for 16-color palette
    pub thickness: u8, // Line thickness 1-3
    pub stroke_type: StrokeType,
    pub start_time: u64, // For animation/replay
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Point {
    pub x: i16,
    pub y: i16,
    pub pressure: u8, // 0-255 for future pressure sensitivity
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StrokeType {
    Line,
    Curve,
    Circle,
    Rectangle,
}

impl VectorPaintCanvas {
    pub fn new(width: u16, height: u16) -> Self {
        Self {
            strokes: Vec::new(),
            canvas_width: width,
            canvas_height: height,
            current_stroke: None,
            cursor: Point {
                x: width as i16 / 2,
                y: height as i16 / 2,
                pressure: 128,
            },
        }
    }

    /// Start a new stroke at cursor position
    pub fn start_stroke(&mut self, color: u8, thickness: u8) {
        let stroke = Stroke {
            points: vec![self.cursor.clone()],
            color,
            thickness,
            stroke_type: StrokeType::Line,
            start_time: chrono::Utc::now().timestamp() as u64,
        };

        self.current_stroke = Some(stroke);
    }

    /// Add point to current stroke (from D-pad movement)
    pub fn add_point_to_stroke(&mut self, direction: Direction) {
        // Move cursor first
        self.move_cursor(direction);

        // Then add to stroke if one is active
        if let Some(ref mut stroke) = self.current_stroke {
            stroke.points.push(self.cursor.clone());
        }
    }

    /// Finish current stroke and save it
    pub fn finish_stroke(&mut self) {
        if let Some(stroke) = self.current_stroke.take() {
            // Only save strokes with multiple points
            if stroke.points.len() > 1 {
                self.strokes.push(stroke);
            }
        }
    }

    /// Move cursor with D-pad (for Game Boy controls)
    pub fn move_cursor(&mut self, direction: Direction) {
        let speed = 2; // Pixels per D-pad press

        match direction {
            Direction::Up => self.cursor.y = (self.cursor.y - speed).max(0),
            Direction::Down => {
                self.cursor.y = (self.cursor.y + speed).min(self.canvas_height as i16 - 1)
            }
            Direction::Left => self.cursor.x = (self.cursor.x - speed).max(0),
            Direction::Right => {
                self.cursor.x = (self.cursor.x + speed).min(self.canvas_width as i16 - 1)
            }
            Direction::UpLeft => {
                self.cursor.x = (self.cursor.x - speed).max(0);
                self.cursor.y = (self.cursor.y - speed).max(0);
            }
            Direction::UpRight => {
                self.cursor.x = (self.cursor.x + speed).min(self.canvas_width as i16 - 1);
                self.cursor.y = (self.cursor.y - speed).max(0);
            }
            Direction::DownLeft => {
                self.cursor.x = (self.cursor.x - speed).max(0);
                self.cursor.y = (self.cursor.y + speed).min(self.canvas_height as i16 - 1);
            }
            Direction::DownRight => {
                self.cursor.x = (self.cursor.x + speed).min(self.canvas_width as i16 - 1);
                self.cursor.y = (self.cursor.y + speed).min(self.canvas_height as i16 - 1);
            }
        }
    }

    /// Render to ASCII for terminal display (like the text editor)
    pub fn render_ascii(&self) -> String {
        let mut grid = vec![vec![' '; self.canvas_width as usize]; self.canvas_height as usize];

        // Draw all strokes as connected lines
        for stroke in &self.strokes {
            self.draw_stroke_to_grid(&mut grid, stroke);
        }

        // Draw current stroke if active
        if let Some(ref stroke) = self.current_stroke {
            self.draw_stroke_to_grid(&mut grid, stroke);
        }

        // Draw cursor
        let cursor_char = if self.current_stroke.is_some() {
            '●'
        } else {
            '○'
        };
        if self.cursor.x >= 0
            && self.cursor.y >= 0
            && (self.cursor.x as usize) < self.canvas_width as usize
            && (self.cursor.y as usize) < self.canvas_height as usize
        {
            grid[self.cursor.y as usize][self.cursor.x as usize] = cursor_char;
        }

        // Convert grid to string with Game Boy frame
        let mut output = String::new();
        output.push_str("┌");
        for _ in 0..self.canvas_width {
            output.push('─');
        }
        output.push_str("┐\n");

        for row in grid {
            output.push('│');
            for cell in row {
                output.push(cell);
            }
            output.push_str("│\n");
        }

        output.push_str("└");
        for _ in 0..self.canvas_width {
            output.push('─');
        }
        output.push('┘');

        output
    }

    fn draw_stroke_to_grid(&self, grid: &mut Vec<Vec<char>>, stroke: &Stroke) {
        // Simple line drawing between consecutive points
        for window in stroke.points.windows(2) {
            let start = &window[0];
            let end = &window[1];

            // Bresenham-style line drawing (simplified)
            let dx = (end.x - start.x).abs();
            let dy = (end.y - start.y).abs();
            let steps = dx.max(dy);

            if steps > 0 {
                for i in 0..=steps {
                    let t = i as f32 / steps as f32;
                    let x = (start.x as f32 + t * (end.x - start.x) as f32) as usize;
                    let y = (start.y as f32 + t * (end.y - start.y) as f32) as usize;

                    if x < self.canvas_width as usize && y < self.canvas_height as usize {
                        // Use different characters based on color
                        let char = match stroke.color % 4 {
                            0 => '█', // Solid
                            1 => '▓', // Dense
                            2 => '▒', // Medium
                            3 => '░', // Light
                            _ => '·', // Dot
                        };
                        grid[y][x] = char;
                    }
                }
            }
        }
    }

    /// Convert drawing to compact format for network transmission
    pub fn to_compact_format(&self) -> Vec<u8> {
        // Serialize strokes to minimal binary format
        // Much smaller than pixel data for network/storage
        serde_json::to_vec(self).unwrap_or_default()
    }

    /// Restore from compact format
    pub fn from_compact_format(data: &[u8]) -> Option<Self> {
        serde_json::from_slice(data).ok()
    }

    /// Memory usage in bytes (just the vector data)
    pub fn memory_usage(&self) -> usize {
        let stroke_size = std::mem::size_of::<Stroke>();
        let point_size = std::mem::size_of::<Point>();

        let mut total = std::mem::size_of::<Self>();

        for stroke in &self.strokes {
            total += stroke_size + (stroke.points.len() * point_size);
        }

        total
    }
}

#[derive(Debug, Clone, Copy)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

impl Direction {
    /// Convert from Game Boy D-pad input
    pub fn from_dpad(up: bool, down: bool, left: bool, right: bool) -> Option<Direction> {
        match (up, down, left, right) {
            (true, false, false, false) => Some(Direction::Up),
            (false, true, false, false) => Some(Direction::Down),
            (false, false, true, false) => Some(Direction::Left),
            (false, false, false, true) => Some(Direction::Right),
            (true, false, true, false) => Some(Direction::UpLeft),
            (true, false, false, true) => Some(Direction::UpRight),
            (false, true, true, false) => Some(Direction::DownLeft),
            (false, true, false, true) => Some(Direction::DownRight),
            _ => None, // No movement or conflicting input
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vector_paint_memory_efficiency() {
        let mut canvas = VectorPaintCanvas::new(160, 144); // Game Boy Advance resolution

        // Draw a simple line
        canvas.start_stroke(1, 2);
        for _ in 0..10 {
            canvas.add_point_to_stroke(Direction::Right);
        }
        canvas.finish_stroke();

        // Memory usage should be minimal (just 10 points + metadata)
        let usage = canvas.memory_usage();
        assert!(usage < 1000); // Much less than 160*144 pixels

        // Should be able to render
        let ascii = canvas.render_ascii();
        assert!(ascii.contains("▓")); // Should contain line characters
    }

    #[test]
    fn test_compact_serialization() {
        let mut canvas = VectorPaintCanvas::new(20, 10);
        canvas.start_stroke(2, 1);
        canvas.add_point_to_stroke(Direction::Right);
        canvas.add_point_to_stroke(Direction::Down);
        canvas.finish_stroke();

        let compact = canvas.to_compact_format();
        let restored = VectorPaintCanvas::from_compact_format(&compact).unwrap();

        assert_eq!(canvas.strokes.len(), restored.strokes.len());
        assert_eq!(
            canvas.strokes[0].points.len(),
            restored.strokes[0].points.len()
        );
    }
}

/// Main paint application with P2P integration
pub struct AnbernicPaintApp {
    pub canvas: VectorPaintCanvas,
    pub current_tool: PaintTool,
    pub current_color: u8,
    pub current_thickness: u8,
    pub ui_state: PaintUIState,
    pub selected_index: usize,

    // P2P mesh networking
    pub p2p_manager: Option<P2PMeshManager>,
    pub p2p_enabled: bool,
    pub shared_artworks: Vec<SharedFile>,
    pub collaborative_sessions: Vec<CollaborativeArtSession>,

    // File management
    pub current_file: Option<PathBuf>,
    pub auto_save_enabled: bool,
    pub recent_files: std::collections::VecDeque<PathBuf>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PaintTool {
    Pen,
    Line,
    Circle,
    Rectangle,
    Eraser,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PaintUIState {
    Drawing,
    ToolMenu,
    ColorPalette,
    FileMenu,
    P2PBrowser,
    P2PCollaboration,
    Settings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollaborativeArtSession {
    pub session_id: String,
    pub title: String,
    pub participants: Vec<String>,
    pub canvas_state: VectorPaintCanvas,
    pub last_modified: u64,
    pub owner: String,
}

impl AnbernicPaintApp {
    pub fn new(width: u16, height: u16) -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            canvas: VectorPaintCanvas::new(width, height),
            current_tool: PaintTool::Pen,
            current_color: 1, // Default black
            current_thickness: 1,
            ui_state: PaintUIState::Drawing,
            selected_index: 0,
            p2p_manager: None,
            p2p_enabled: true,
            shared_artworks: Vec::new(),
            collaborative_sessions: Vec::new(),
            current_file: None,
            auto_save_enabled: true,
            recent_files: std::collections::VecDeque::with_capacity(10),
        })
    }

    /// Initialize P2P mesh networking for paint app
    pub async fn initialize_p2p(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let device_name = format!("Anbernic-Paint-{}", std::process::id());
        let device_type = DeviceType::Anbernic("Paint App".to_string());

        let mut p2p_manager = P2PMeshManager::new(device_name, device_type)?;
        p2p_manager.start().await?;

        self.p2p_manager = Some(p2p_manager);
        log::info!("P2P mesh networking initialized for paint app");
        Ok(())
    }

    /// Share current artwork via P2P
    pub async fn share_artwork(
        &mut self,
        title: String,
        description: Option<String>,
    ) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            // Save canvas to temporary file
            let temp_path = self.save_canvas_to_temp().await?;

            let tags = vec![
                "artwork".to_string(),
                "paint".to_string(),
                "anbernic".to_string(),
            ];
            let file_id = p2p_manager.share_file(temp_path, description, tags).await?;

            // Update shared artworks cache
            self.refresh_shared_artworks().await?;

            log::info!("Artwork shared: {} ({})", title, file_id);
            Ok(file_id)
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Request artwork from a peer
    pub async fn request_artwork(
        &mut self,
        file_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            p2p_manager.request_file(file_id.clone(), peer_id.clone()).await?;
            log::info!("Requested artwork {} from peer {}", file_id, peer_id);
            Ok(())
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Start collaborative art session
    pub async fn start_collaborative_session(
        &mut self,
        title: String,
    ) -> Result<String, Box<dyn std::error::Error>> {
        let session_id = format!(
            "art_session_{}_{}",
            std::process::id(),
            chrono::Utc::now().timestamp()
        );

        let session = CollaborativeArtSession {
            session_id: session_id.clone(),
            title,
            participants: vec![self.get_device_id()],
            canvas_state: self.canvas.clone(),
            last_modified: chrono::Utc::now().timestamp() as u64,
            owner: self.get_device_id(),
        };

        self.collaborative_sessions.push(session);

        // Share session with peers
        if let Some(p2p_manager) = &self.p2p_manager {
            let session_data = serde_json::to_vec(&self.collaborative_sessions.last().unwrap())?;
            let temp_path = self
                .save_data_to_temp(&session_data, "collaborative_session.json")
                .await?;

            let tags = vec!["collaboration".to_string(), "art".to_string()];
            let description = Some(format!("Collaborative art session: {}", session_id));
            p2p_manager.share_file(temp_path, description, tags).await?;
        }

        log::info!("Started collaborative art session: {}", session_id);
        Ok(session_id)
    }

    /// Join existing collaborative session
    pub async fn join_collaborative_session(
        &mut self,
        session_id: String,
        peer_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            // Find the session file from peer's shared files
            let peers = p2p_manager.get_peers().await;
            for peer in peers {
                if peer.device_id == peer_id {
                    for shared_file in &peer.shared_files {
                        if shared_file.tags.contains(&"collaboration".to_string())
                            && shared_file
                                .description
                                .as_ref()
                                .map_or(false, |desc| desc.contains(&session_id))
                        {
                            // Request the session file
                            p2p_manager
                                .request_file(shared_file.id.clone(), peer_id.clone())
                                .await?;
                            break;
                        }
                    }
                }
            }

            log::info!("Joining collaborative session: {}", session_id);
            Ok(())
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Sync collaborative canvas changes
    pub async fn sync_collaborative_canvas(
        &mut self,
        session_id: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(session) = self
            .collaborative_sessions
            .iter_mut()
            .find(|s| s.session_id == session_id)
        {
            // Update session with current canvas state
            session.canvas_state = self.canvas.clone();
            session.last_modified = chrono::Utc::now().timestamp() as u64;

            // Share updated session
            if let Some(p2p_manager) = &self.p2p_manager {
                let session_data = serde_json::to_vec(session)?;
                let temp_path = self
                    .save_data_to_temp(&session_data, "collaborative_session.json")
                    .await?;

                let tags = vec!["collaboration".to_string(), "art".to_string()];
                let description =
                    Some(format!("Updated collaborative art session: {}", session_id));
                p2p_manager.share_file(temp_path, description, tags).await?;
            }
        }

        Ok(())
    }

    /// Search for shared artworks across the mesh
    pub async fn search_artworks(
        &mut self,
        query: String,
    ) -> Result<Vec<SharedFile>, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let file_types = vec!["json".to_string(), "paint".to_string()];
            let results = p2p_manager.search_files(query, file_types).await?;

            // Filter for artwork files
            let artwork_results: Vec<SharedFile> = results
                .into_iter()
                .filter(|file| {
                    file.tags.contains(&"artwork".to_string())
                        || file.tags.contains(&"paint".to_string())
                })
                .collect();

            Ok(artwork_results)
        } else {
            Err("P2P not initialized".into())
        }
    }

    /// Save current canvas state
    pub async fn save_canvas(
        &mut self,
        file_path: PathBuf,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let canvas_data = self.canvas.to_compact_format();
        tokio::fs::write(&file_path, canvas_data).await?;

        self.current_file = Some(file_path.clone());
        self.add_to_recent_files(file_path);

        log::info!("Canvas saved to {:?}", self.current_file);
        Ok(())
    }

    /// Load canvas from file
    pub async fn load_canvas(
        &mut self,
        file_path: PathBuf,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let canvas_data = tokio::fs::read(&file_path).await?;

        if let Some(canvas) = VectorPaintCanvas::from_compact_format(&canvas_data) {
            self.canvas = canvas;
            self.current_file = Some(file_path.clone());
            self.add_to_recent_files(file_path);

            log::info!("Canvas loaded from {:?}", self.current_file);
            Ok(())
        } else {
            Err("Failed to parse canvas file".into())
        }
    }

    /// Handle paint application input
    pub async fn handle_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match self.ui_state {
            PaintUIState::Drawing => self.handle_drawing_input(button).await?,
            PaintUIState::ToolMenu => self.handle_tool_menu_input(button)?,
            PaintUIState::ColorPalette => self.handle_color_input(button)?,
            PaintUIState::FileMenu => self.handle_file_menu_input(button).await?,
            PaintUIState::P2PBrowser => self.handle_p2p_browser_input(button).await?,
            PaintUIState::P2PCollaboration => self.handle_collaboration_input(button).await?,
            PaintUIState::Settings => self.handle_settings_input(button)?,
        }
        Ok(())
    }

    async fn handle_drawing_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                // Start/continue drawing
                match self.current_tool {
                    PaintTool::Pen => {
                        if self.canvas.current_stroke.is_none() {
                            self.canvas
                                .start_stroke(self.current_color, self.current_thickness);
                        }
                    }
                    _ => {}
                }
            }
            PaintButton::B => {
                // Stop drawing or cancel
                self.canvas.finish_stroke();
            }
            PaintButton::L => {
                // Previous tool/color
                self.ui_state = PaintUIState::ToolMenu;
            }
            PaintButton::R => {
                // Next tool/color or file menu
                self.ui_state = PaintUIState::FileMenu;
            }
            PaintButton::Up => {
                self.canvas.move_cursor(Direction::Up);
                if self.canvas.current_stroke.is_some() {
                    self.canvas.add_point_to_stroke(Direction::Up);
                }
            }
            PaintButton::Down => {
                self.canvas.move_cursor(Direction::Down);
                if self.canvas.current_stroke.is_some() {
                    self.canvas.add_point_to_stroke(Direction::Down);
                }
            }
            PaintButton::Left => {
                self.canvas.move_cursor(Direction::Left);
                if self.canvas.current_stroke.is_some() {
                    self.canvas.add_point_to_stroke(Direction::Left);
                }
            }
            PaintButton::Right => {
                self.canvas.move_cursor(Direction::Right);
                if self.canvas.current_stroke.is_some() {
                    self.canvas.add_point_to_stroke(Direction::Right);
                }
            }
            PaintButton::Select => {
                // Toggle between drawing and P2P browser
                if self.p2p_enabled {
                    self.ui_state = PaintUIState::P2PBrowser;
                }
            }
            PaintButton::Start => {
                // Open collaborative session menu
                if self.p2p_enabled {
                    self.ui_state = PaintUIState::P2PCollaboration;
                }
            }
        }

        // Auto-save if enabled
        if self.auto_save_enabled && self.current_file.is_some() {
            if let Some(file_path) = &self.current_file.clone() {
                self.save_canvas(file_path.clone()).await?;
            }
        }

        Ok(())
    }

    fn handle_tool_menu_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                match self.selected_index {
                    0 => self.current_tool = PaintTool::Pen,
                    1 => self.current_tool = PaintTool::Line,
                    2 => self.current_tool = PaintTool::Circle,
                    3 => self.current_tool = PaintTool::Rectangle,
                    4 => self.current_tool = PaintTool::Eraser,
                    _ => {}
                }
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::Up => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            PaintButton::Down => {
                if self.selected_index < 4 {
                    self.selected_index += 1;
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_color_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                self.current_color = self.selected_index as u8;
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::Up => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            PaintButton::Down => {
                if self.selected_index < 15 {
                    self.selected_index += 1;
                }
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_file_menu_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                match self.selected_index {
                    0 => {
                        // Save current artwork
                        if let Some(file_path) = &self.current_file.clone() {
                            self.save_canvas(file_path.clone()).await?;
                        }
                    }
                    1 => {
                        // Share via P2P
                        if self.p2p_enabled {
                            let title = format!("Artwork_{}", chrono::Utc::now().timestamp());
                            self.share_artwork(title, None).await?;
                        }
                    }
                    _ => {}
                }
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_p2p_browser_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                // Request selected artwork
                if let Some(artwork) = self.shared_artworks.get(self.selected_index) {
                    // Find peer who shared this artwork
                    if let Some(p2p_manager) = &self.p2p_manager {
                        let peers = p2p_manager.get_peers().await;
                        for peer in peers {
                            if peer.shared_files.iter().any(|f| f.id == artwork.id) {
                                self.request_artwork(artwork.id.clone(), peer.device_id)
                                    .await?;
                                break;
                            }
                        }
                    }
                }
            }
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::Up => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            PaintButton::Down => {
                if self.selected_index < self.shared_artworks.len().saturating_sub(1) {
                    self.selected_index += 1;
                }
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_collaboration_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::A => {
                match self.selected_index {
                    0 => {
                        // Start new collaboration
                        let title = format!("Collab_{}", chrono::Utc::now().timestamp());
                        self.start_collaborative_session(title).await?;
                    }
                    1 => {
                        // Join existing collaboration (simplified - would show list)
                        // Implementation would show available sessions
                    }
                    _ => {}
                }
                self.ui_state = PaintUIState::Drawing;
            }
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            _ => {}
        }
        Ok(())
    }

    fn handle_settings_input(
        &mut self,
        button: PaintButton,
    ) -> Result<(), Box<dyn std::error::Error>> {
        match button {
            PaintButton::B | PaintButton::L => {
                self.ui_state = PaintUIState::Drawing;
            }
            _ => {}
        }
        Ok(())
    }

    /// Utility functions

    async fn save_canvas_to_temp(&self) -> Result<PathBuf, Box<dyn std::error::Error>> {
        let temp_dir = std::env::temp_dir();
        let filename = format!(
            "artwork_{}_{}.paint",
            std::process::id(),
            chrono::Utc::now().timestamp()
        );
        let temp_path = temp_dir.join(filename);

        let canvas_data = self.canvas.to_compact_format();
        tokio::fs::write(&temp_path, canvas_data).await?;

        Ok(temp_path)
    }

    async fn save_data_to_temp(
        &self,
        data: &[u8],
        filename: &str,
    ) -> Result<PathBuf, Box<dyn std::error::Error>> {
        let temp_dir = std::env::temp_dir();
        let temp_path = temp_dir.join(filename);
        tokio::fs::write(&temp_path, data).await?;
        Ok(temp_path)
    }

    async fn refresh_shared_artworks(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let all_files = p2p_manager.get_available_files().await;
            self.shared_artworks = all_files
                .into_iter()
                .filter(|file| {
                    file.tags.contains(&"artwork".to_string())
                        || file.tags.contains(&"paint".to_string())
                })
                .collect();
        }
        Ok(())
    }

    fn get_device_id(&self) -> String {
        self.p2p_manager
            .as_ref()
            .map(|pm| pm.device_info.device_id.clone())
            .unwrap_or_else(|| format!("paint_{}", std::process::id()))
    }

    fn add_to_recent_files(&mut self, file_path: PathBuf) {
        // Remove if already exists
        self.recent_files.retain(|f| f != &file_path);

        // Add to front
        self.recent_files.push_front(file_path);

        // Keep only last 10 files
        while self.recent_files.len() > 10 {
            self.recent_files.pop_back();
        }
    }

    /// Render the paint application UI
    pub fn render_display(&self) -> String {
        let mut display = String::new();

        display.push_str("🎨 ANBERNIC PAINT 🎨\n\n");

        match self.ui_state {
            PaintUIState::Drawing => {
                display.push_str(&self.canvas.render_ascii());
                display.push_str(&format!(
                    "\nTool: {:?} | Color: {} | Thickness: {}",
                    self.current_tool, self.current_color, self.current_thickness
                ));

                if self.p2p_enabled {
                    display.push_str(&format!(
                        "\nPeers: {} | Shared: {}",
                        self.get_peer_count(),
                        self.shared_artworks.len()
                    ));
                }
            }
            PaintUIState::ToolMenu => {
                display.push_str("Select Tool:\n");
                let tools = ["Pen", "Line", "Circle", "Rectangle", "Eraser"];
                for (i, tool) in tools.iter().enumerate() {
                    let prefix = if i == self.selected_index {
                        "► "
                    } else {
                        "  "
                    };
                    display.push_str(&format!("{}{}\n", prefix, tool));
                }
            }
            PaintUIState::P2PBrowser => {
                display.push_str("🌐 P2P Artworks:\n");
                if self.shared_artworks.is_empty() {
                    display.push_str("No artworks found. Share some!");
                } else {
                    for (i, artwork) in self.shared_artworks.iter().take(10).enumerate() {
                        let prefix = if i == self.selected_index {
                            "► "
                        } else {
                            "  "
                        };
                        display.push_str(&format!(
                            "{}{} by {}\n",
                            prefix, artwork.filename, artwork.shared_by
                        ));
                    }
                }
            }
            PaintUIState::P2PCollaboration => {
                display.push_str("🤝 Collaboration:\n");
                display.push_str("► Start New Session\n");
                display.push_str("  Join Session\n");

                if !self.collaborative_sessions.is_empty() {
                    display.push_str("\nActive Sessions:\n");
                    for session in &self.collaborative_sessions {
                        display.push_str(&format!(
                            "• {} ({} participants)\n",
                            session.title,
                            session.participants.len()
                        ));
                    }
                }
            }
            _ => {
                display.push_str(&format!("State: {:?}", self.ui_state));
            }
        }

        display
    }

    fn get_peer_count(&self) -> usize {
        // Use the peers field instead of non-existent mesh_peers_cache
        if let Some(pm) = &self.p2p_manager {
            tokio::runtime::Runtime::new()
                .unwrap()
                .block_on(async { pm.get_peers().await.len() })
        } else {
            0
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PaintButton {
    A,
    B,
    L,
    R,
    Up,
    Down,
    Left,
    Right,
    Select,
    Start,
}

impl P2PIntegration for AnbernicPaintApp {
    fn get_p2p_manager(&self) -> &P2PMeshManager {
        self.p2p_manager
            .as_ref()
            .expect("P2P manager not initialized")
    }

    async fn share_file(&self, file_path: PathBuf) -> Result<String, Box<dyn std::error::Error>> {
        if let Some(p2p_manager) = &self.p2p_manager {
            let tags = vec!["artwork".to_string(), "paint".to_string()];
            p2p_manager.share_file(file_path, None, tags).await
        } else {
            Err("P2P not initialized".into())
        }
    }
}
