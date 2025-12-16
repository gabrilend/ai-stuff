use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Musical instrument system with user-definable keymaps
/// Stores notes as events, not audio data - perfect for Anbernic constraints
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MusicalInstrument {
    pub name: String,
    pub keymap: GamepadKeymap,
    pub current_recording: Option<Recording>,
    pub recordings: Vec<Recording>,
    pub metronome: Metronome,
    pub session_start: DateTime<Utc>,
}

/// Maps gamepad buttons to musical notes/actions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GamepadKeymap {
    pub name: String,
    pub notes: HashMap<GamepadButton, Note>,
    pub modifiers: HashMap<GamepadButton, Modifier>,
    pub password_combo: Vec<GamepadButton>, // Return to main menu
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum GamepadButton {
    A,
    B,
    X,
    Y,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
    L1,
    R1,
    L2,
    R2,
    Select,
    Start,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub frequency: f32, // Hz - fundamental frequency
    pub name: String,   // "C4", "F#3", etc.
    pub octave: u8,
    pub velocity: u8,   // 0-127 MIDI style
    pub timbre: Timbre, // Waveform characteristics
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Timbre {
    Sine,
    Square,
    Sawtooth,
    Triangle,
    Noise,
    Custom(Vec<f32>), // Harmonic series
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Modifier {
    Octave(i8),    // Shift octave up/down
    Volume(f32),   // Volume multiplier
    Sustain(bool), // Hold notes
    Tremolo(f32),  // Amplitude modulation
    Vibrato(f32),  // Frequency modulation
}

/// Recording session with metronome and note events
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recording {
    pub id: String,
    pub name: String,
    pub events: Vec<NoteEvent>,
    pub bpm: u16,
    pub time_signature: (u8, u8), // 4/4, 3/4, etc.
    pub duration_ms: u64,
    pub recorded_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoteEvent {
    pub note: Note,
    pub timestamp_ms: u64, // Relative to recording start
    pub duration_ms: u64,  // How long the note was held
    pub button: GamepadButton,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metronome {
    pub bpm: u16,
    pub enabled: bool,
    pub countdown_beats: u8, // Beats before recording starts
    pub accent_every: u8,    // Accent every N beats
    pub sound: MetronomeSound,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum MetronomeSound {
    Click,
    Beep,
    Tick,
    Custom(f32), // Frequency
}

impl MusicalInstrument {
    pub fn new(name: String, keymap: GamepadKeymap) -> Self {
        Self {
            name,
            keymap,
            current_recording: None,
            recordings: Vec::new(),
            metronome: Metronome::default(),
            session_start: Utc::now(),
        }
    }

    /// Check if recording combo is being held (L+R+SELECT)
    pub fn is_recording_combo(&self, pressed: &[GamepadButton]) -> bool {
        pressed.contains(&GamepadButton::L1)
            && pressed.contains(&GamepadButton::R1)
            && pressed.contains(&GamepadButton::Select)
    }

    /// Check if password combo matches (return to main menu)
    pub fn is_password_combo(&self, sequence: &[GamepadButton]) -> bool {
        if sequence.len() < self.keymap.password_combo.len() {
            return false;
        }

        let tail = &sequence[sequence.len() - self.keymap.password_combo.len()..];
        tail == self.keymap.password_combo
    }

    /// Start recording with metronome countdown
    pub fn start_recording(&mut self, name: String) -> Result<(), String> {
        if self.current_recording.is_some() {
            return Err("Already recording".to_string());
        }

        let recording = Recording {
            id: format!("rec_{}", chrono::Utc::now().timestamp()),
            name,
            events: Vec::new(),
            bpm: self.metronome.bpm,
            time_signature: (4, 4), // Default 4/4
            duration_ms: 0,
            recorded_at: Utc::now(),
        };

        self.current_recording = Some(recording);
        Ok(())
    }

    /// Stop recording and save
    pub fn stop_recording(&mut self) -> Result<Recording, String> {
        match self.current_recording.take() {
            Some(mut recording) => {
                if let Some(last_event) = recording.events.last() {
                    recording.duration_ms = last_event.timestamp_ms + last_event.duration_ms;
                }

                let saved_recording = recording.clone();
                self.recordings.push(recording);
                Ok(saved_recording)
            }
            None => Err("No active recording".to_string()),
        }
    }

    /// Play a note (when button pressed)
    pub fn press_button(&mut self, button: GamepadButton, timestamp_ms: u64) -> Option<Note> {
        if let Some(note) = self.keymap.notes.get(&button) {
            let mut final_note = note.clone();

            // Apply modifiers
            for (mod_button, modifier) in &self.keymap.modifiers {
                // In real implementation, check if modifier button is held
                self.apply_modifier(&mut final_note, modifier);
            }

            // Record if recording is active
            if let Some(ref mut recording) = self.current_recording {
                let event = NoteEvent {
                    note: final_note.clone(),
                    timestamp_ms,
                    duration_ms: 0, // Will be set on release
                    button,
                };
                recording.events.push(event);
            }

            Some(final_note)
        } else {
            None
        }
    }

    /// Release button (note off)
    pub fn release_button(&mut self, button: GamepadButton, timestamp_ms: u64) {
        if let Some(ref mut recording) = self.current_recording {
            // Find the most recent event for this button and set duration
            for event in recording.events.iter_mut().rev() {
                if event.button == button && event.duration_ms == 0 {
                    event.duration_ms = timestamp_ms.saturating_sub(event.timestamp_ms);
                    break;
                }
            }
        }
    }

    fn apply_modifier(&self, note: &mut Note, modifier: &Modifier) {
        match modifier {
            Modifier::Octave(shift) => {
                let new_octave = (note.octave as i8 + shift).clamp(0, 9) as u8;
                let freq_multiplier = 2.0_f32.powi((new_octave as i32) - (note.octave as i32));
                note.frequency *= freq_multiplier;
                note.octave = new_octave;
            }
            Modifier::Volume(vol) => {
                note.velocity = ((note.velocity as f32) * vol).clamp(0.0, 127.0) as u8;
            }
            Modifier::Sustain(_) => {
                // Sustain handling would be in the audio engine
            }
            Modifier::Tremolo(_) | Modifier::Vibrato(_) => {
                // Modulation effects would be applied in real-time
            }
        }
    }

    /// Get ASCII representation of current state
    pub fn render_display(&self) -> String {
        let mut output = String::new();

        // Header with instrument info
        output.push_str(&format!(
            "🎵 {} | BPM: {} | Notes: {}\n",
            self.name,
            self.metronome.bpm,
            self.keymap.notes.len()
        ));

        if let Some(ref recording) = self.current_recording {
            output.push_str(&format!(
                "🔴 REC: {} | Events: {}\n",
                recording.name,
                recording.events.len()
            ));
        } else {
            output.push_str("⏹️  Ready to play\n");
        }

        output.push_str("\n");

        // Gamepad layout visualization
        output.push_str("┌─────────────────────┐\n");
        output.push_str("│    [Y]     [X]      │\n");
        output.push_str("│      [A] [B]        │\n");
        output.push_str("│                     │\n");
        output.push_str("│ ↑     [SEL][STA]    │\n");
        output.push_str("│←→↓    [L1] [R1]     │\n");
        output.push_str("└─────────────────────┘\n");

        // Show current keymap
        output.push_str("\n🎹 Current Keymap:\n");
        for (button, note) in &self.keymap.notes {
            output.push_str(&format!(
                "  {:?}: {} ({:.1}Hz)\n",
                button, note.name, note.frequency
            ));
        }

        if self.metronome.enabled {
            output.push_str(&format!("\n⏱️  Metronome: {} BPM\n", self.metronome.bpm));
        }

        // Recording instructions
        output.push_str("\n🎮 Controls:\n");
        output.push_str("  L+R+SELECT: Start/Stop Recording\n");
        output.push_str("  Password combo: Return to menu\n");

        output
    }

    /// Save instrument state to shared config file
    pub fn save_to_config(&self, filename: &str) -> Result<(), Box<dyn std::error::Error>> {
        let config_path = format!("files/build/{}", filename);
        let json = serde_json::to_string_pretty(self)?;
        std::fs::write(config_path, json)?;
        Ok(())
    }

    /// Load from shared config file (living RAM)
    pub fn load_from_config(filename: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let config_path = format!("files/build/{}", filename);
        let json = std::fs::read_to_string(config_path)?;
        let instrument = serde_json::from_str(&json)?;
        Ok(instrument)
    }

    /// Force senescence - clear volatile state when "sleeping"
    pub fn force_senescence(&mut self) {
        // Clear recordings (conversation context)
        self.recordings.clear();
        self.current_recording = None;

        // Reset session
        self.session_start = Utc::now();

        // Keep keymap and instrument settings (persistent)
    }
}

impl Default for Metronome {
    fn default() -> Self {
        Self {
            bpm: 120,
            enabled: false,
            countdown_beats: 4,
            accent_every: 4,
            sound: MetronomeSound::Click,
        }
    }
}

/// Built-in instrument presets
impl GamepadKeymap {
    /// Piano-style layout
    pub fn piano() -> Self {
        let mut notes = HashMap::new();

        // White keys
        notes.insert(GamepadButton::A, Note::c4());
        notes.insert(GamepadButton::B, Note::d4());
        notes.insert(GamepadButton::X, Note::e4());
        notes.insert(GamepadButton::Y, Note::f4());
        notes.insert(GamepadButton::L1, Note::g4());
        notes.insert(GamepadButton::R1, Note::a4());
        notes.insert(GamepadButton::L2, Note::b4());
        notes.insert(GamepadButton::R2, Note::c5());

        // Black keys (sharps)
        notes.insert(GamepadButton::DPadUp, Note::cs4());
        notes.insert(GamepadButton::DPadDown, Note::ds4());
        notes.insert(GamepadButton::DPadLeft, Note::fs4());
        notes.insert(GamepadButton::DPadRight, Note::gs4());

        let mut modifiers = HashMap::new();
        modifiers.insert(GamepadButton::Select, Modifier::Octave(-1));
        modifiers.insert(GamepadButton::Start, Modifier::Octave(1));

        Self {
            name: "Piano".to_string(),
            notes,
            modifiers,
            password_combo: vec![
                GamepadButton::Start,
                GamepadButton::Select,
                GamepadButton::Start,
                GamepadButton::Select,
            ],
        }
    }

    /// Drum kit layout
    pub fn drums() -> Self {
        let mut notes = HashMap::new();

        notes.insert(GamepadButton::A, Note::kick());
        notes.insert(GamepadButton::B, Note::snare());
        notes.insert(GamepadButton::X, Note::hihat());
        notes.insert(GamepadButton::Y, Note::crash());
        notes.insert(GamepadButton::DPadUp, Note::tom_high());
        notes.insert(GamepadButton::DPadDown, Note::tom_low());
        notes.insert(GamepadButton::DPadLeft, Note::ride());
        notes.insert(GamepadButton::DPadRight, Note::openhat());

        Self {
            name: "Drums".to_string(),
            notes,
            modifiers: HashMap::new(),
            password_combo: vec![
                GamepadButton::L1,
                GamepadButton::R1,
                GamepadButton::L1,
                GamepadButton::R1,
            ],
        }
    }
}

impl Note {
    pub fn c4() -> Self {
        Self::new("C4", 261.63, 4, Timbre::Sine)
    }
    pub fn cs4() -> Self {
        Self::new("C#4", 277.18, 4, Timbre::Sine)
    }
    pub fn d4() -> Self {
        Self::new("D4", 293.66, 4, Timbre::Sine)
    }
    pub fn ds4() -> Self {
        Self::new("D#4", 311.13, 4, Timbre::Sine)
    }
    pub fn e4() -> Self {
        Self::new("E4", 329.63, 4, Timbre::Sine)
    }
    pub fn f4() -> Self {
        Self::new("F4", 349.23, 4, Timbre::Sine)
    }
    pub fn fs4() -> Self {
        Self::new("F#4", 369.99, 4, Timbre::Sine)
    }
    pub fn g4() -> Self {
        Self::new("G4", 392.00, 4, Timbre::Sine)
    }
    pub fn gs4() -> Self {
        Self::new("G#4", 415.30, 4, Timbre::Sine)
    }
    pub fn a4() -> Self {
        Self::new("A4", 440.00, 4, Timbre::Sine)
    }
    pub fn b4() -> Self {
        Self::new("B4", 493.88, 4, Timbre::Sine)
    }
    pub fn c5() -> Self {
        Self::new("C5", 523.25, 5, Timbre::Sine)
    }

    // Drum sounds (using noise and specific frequencies)
    pub fn kick() -> Self {
        Self::new("Kick", 60.0, 2, Timbre::Square)
    }
    pub fn snare() -> Self {
        Self::new("Snare", 200.0, 3, Timbre::Noise)
    }
    pub fn hihat() -> Self {
        Self::new("HiHat", 8000.0, 6, Timbre::Noise)
    }
    pub fn crash() -> Self {
        Self::new("Crash", 5000.0, 6, Timbre::Noise)
    }
    pub fn tom_high() -> Self {
        Self::new("Tom-Hi", 150.0, 3, Timbre::Triangle)
    }
    pub fn tom_low() -> Self {
        Self::new("Tom-Lo", 80.0, 2, Timbre::Triangle)
    }
    pub fn ride() -> Self {
        Self::new("Ride", 3000.0, 5, Timbre::Noise)
    }
    pub fn openhat() -> Self {
        Self::new("Open-Hat", 6000.0, 6, Timbre::Noise)
    }

    fn new(name: &str, frequency: f32, octave: u8, timbre: Timbre) -> Self {
        Self {
            frequency,
            name: name.to_string(),
            octave,
            velocity: 100,
            timbre,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_instrument_creation() {
        let keymap = GamepadKeymap::piano();
        let instrument = MusicalInstrument::new("Test Piano".to_string(), keymap);

        assert_eq!(instrument.name, "Test Piano");
        assert!(instrument.keymap.notes.contains_key(&GamepadButton::A));
    }

    #[test]
    fn test_recording_workflow() {
        let keymap = GamepadKeymap::piano();
        let mut instrument = MusicalInstrument::new("Test".to_string(), keymap);

        // Start recording
        instrument.start_recording("Test Song".to_string()).unwrap();
        assert!(instrument.current_recording.is_some());

        // Play some notes
        instrument.press_button(GamepadButton::A, 0);
        instrument.release_button(GamepadButton::A, 500);

        // Stop recording
        let recording = instrument.stop_recording().unwrap();
        assert_eq!(recording.events.len(), 1);
        assert_eq!(recording.events[0].duration_ms, 500);
    }

    #[test]
    fn test_password_combo() {
        let keymap = GamepadKeymap::piano();
        let instrument = MusicalInstrument::new("Test".to_string(), keymap);

        let correct_sequence = vec![
            GamepadButton::A,
            GamepadButton::Start,
            GamepadButton::Select,
            GamepadButton::Start,
            GamepadButton::Select,
        ];

        assert!(instrument.is_password_combo(&correct_sequence));
    }
}
