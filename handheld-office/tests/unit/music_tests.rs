use handheld_office::*;
use std::io::Cursor;
use std::time::Duration;

#[cfg(test)]
mod music_tests {
    use super::*;

    #[test]
    fn test_pattern_creation_and_validation() {
        let pattern = Pattern::new(64, 4); // 64 rows, 4 channels
        
        assert_eq!(pattern.length, 64);
        assert_eq!(pattern.channels, 4);
        assert_eq!(pattern.data.len(), 256); // 64 * 4
        
        // All note data should be initialized to empty
        assert!(pattern.data.iter().all(|note| note.is_empty()));
    }

    #[test]
    fn test_pattern_note_insertion_and_removal() {
        let mut pattern = Pattern::new(32, 2);
        
        let note = Note {
            pitch: 60, // Middle C
            octave: 4,
            instrument: 1,
            volume: 64,
            effects: Vec::new(),
        };
        
        // Insert note
        pattern.set_note(0, 0, Some(note.clone()));
        
        let retrieved = pattern.get_note(0, 0).unwrap();
        assert_eq!(retrieved.pitch, 60);
        assert_eq!(retrieved.octave, 4);
        assert_eq!(retrieved.instrument, 1);
        assert_eq!(retrieved.volume, 64);
        
        // Remove note
        pattern.set_note(0, 0, None);
        assert!(pattern.get_note(0, 0).is_none());
    }

    #[test]
    fn test_pattern_boundary_validation() {
        let pattern = Pattern::new(16, 4);
        
        // Valid boundaries
        assert!(pattern.is_valid_position(0, 0));
        assert!(pattern.is_valid_position(15, 3));
        
        // Invalid boundaries
        assert!(!pattern.is_valid_position(16, 0));
        assert!(!pattern.is_valid_position(0, 4));
        assert!(!pattern.is_valid_position(100, 100));
    }

    #[test]
    fn test_tempo_bpm_calculations() {
        let mut tracker = TrackerEngine::new();
        
        // Set BPM and verify calculations
        tracker.set_bpm(120);
        assert_eq!(tracker.bpm, 120);
        
        // Calculate samples per tick at 44.1kHz
        let samples_per_tick = tracker.calculate_samples_per_tick(44100);
        assert!(samples_per_tick > 0);
        
        // Verify tempo changes
        tracker.set_bpm(240);
        let new_samples_per_tick = tracker.calculate_samples_per_tick(44100);
        assert!(new_samples_per_tick < samples_per_tick); // Higher BPM = fewer samples per tick
    }

    #[test]
    fn test_instrument_creation_and_properties() {
        let mut instrument = Instrument::new("Test Synth");
        
        assert_eq!(instrument.name, "Test Synth");
        assert_eq!(instrument.volume, 64); // Default volume
        
        // Test ADSR envelope
        instrument.envelope.attack = 0.1;
        instrument.envelope.decay = 0.2;
        instrument.envelope.sustain = 0.7;
        instrument.envelope.release = 0.5;
        
        assert_eq!(instrument.envelope.attack, 0.1);
        assert_eq!(instrument.envelope.sustain, 0.7);
    }

    #[test]
    fn test_sample_loading_and_validation() {
        let mut instrument = Instrument::new("Sampled Instrument");
        
        // Create test sample data (1 second of 44.1kHz audio)
        let sample_rate = 44100;
        let sample_data: Vec<f32> = (0..sample_rate)
            .map(|i| (i as f32 * 440.0 * 2.0 * std::f32::consts::PI / sample_rate as f32).sin() * 0.5)
            .collect();
        
        instrument.load_sample(sample_data, sample_rate);
        
        assert_eq!(instrument.sample_rate, sample_rate);
        assert_eq!(instrument.sample_data.len(), sample_rate as usize);
        assert!(!instrument.sample_data.is_empty());
    }

    #[test]
    fn test_audio_mixing_multiple_channels() {
        let mut mixer = MixingEngine::new(44100, 2); // 44.1kHz stereo
        
        // Create test channels with different frequencies
        let mut channel1 = Channel::new();
        let mut channel2 = Channel::new();
        
        channel1.play_note(60, 1, 64); // Middle C
        channel2.play_note(64, 1, 64); // E
        
        mixer.add_channel(channel1);
        mixer.add_channel(channel2);
        
        // Generate mixed audio buffer
        let buffer_size = 1024;
        let mixed_buffer = mixer.mix_audio(buffer_size);
        
        assert_eq!(mixed_buffer.len(), buffer_size * 2); // Stereo
        
        // Verify audio is not silent (channels are playing)
        let max_amplitude = mixed_buffer.iter().fold(0.0f32, |acc, &x| acc.max(x.abs()));
        assert!(max_amplitude > 0.0);
    }

    #[test]
    fn test_volume_envelope_calculations() {
        let envelope = Envelope {
            attack: 0.1,   // 100ms attack
            decay: 0.2,    // 200ms decay
            sustain: 0.7,  // 70% sustain level
            release: 0.5,  // 500ms release
        };
        
        // Test attack phase
        let attack_value = envelope.calculate_amplitude(0.05, EnvelopePhase::Attack); // 50ms into attack
        assert!(attack_value > 0.0 && attack_value < 1.0);
        
        // Test sustain phase
        let sustain_value = envelope.calculate_amplitude(1.0, EnvelopePhase::Sustain);
        assert!((sustain_value - 0.7).abs() < 0.01); // Should be close to sustain level
        
        // Test release phase
        let release_value = envelope.calculate_amplitude(0.25, EnvelopePhase::Release); // 250ms into release
        assert!(release_value < 0.7 && release_value > 0.0);
    }

    #[test]
    fn test_frequency_modulation_accuracy() {
        let base_freq = 440.0; // A4
        
        // Test pitch bend
        let bent_freq = apply_pitch_bend(base_freq, 0.5); // Half semitone up
        assert!(bent_freq > base_freq);
        
        // Test vibrato
        let vibrato_freq = apply_vibrato(base_freq, 5.0, 0.1, 0.0); // 5Hz vibrato, 10% depth
        assert!(vibrato_freq != base_freq);
        
        // Test detuning
        let detuned_freq = apply_detune(base_freq, 10); // +10 cents
        assert!(detuned_freq > base_freq);
        assert!((detuned_freq / base_freq - 1.0) < 0.01); // Small change
    }

    #[test]
    fn test_mod_file_parsing() {
        // Create a minimal MOD file header
        let mut mod_data = vec![0u8; 1084]; // Minimum MOD file size
        
        // MOD signature "M.K."
        mod_data[1080..1084].copy_from_slice(b"M.K.");
        
        // Set title
        mod_data[0..20].copy_from_slice(b"Test Song\0\0\0\0\0\0\0\0\0\0\0");
        
        // Set number of patterns
        mod_data[950] = 1; // Song length
        mod_data[951] = 0; // Restart position
        
        let cursor = Cursor::new(mod_data);
        let result = ModParser::parse(cursor);
        
        assert!(result.is_ok());
        let mod_file = result.unwrap();
        
        assert_eq!(mod_file.title.trim_end_matches('\0'), "Test Song");
        assert_eq!(mod_file.song_length, 1);
    }

    #[test]
    fn test_pattern_playback_timing() {
        let mut tracker = TrackerEngine::new();
        tracker.set_bpm(120);
        tracker.set_speed(6); // 6 ticks per row
        
        let mut pattern = Pattern::new(64, 4);
        
        // Add notes at specific positions
        let note = Note::new(60, 4, 1, 64);
        pattern.set_note(0, 0, Some(note.clone()));
        pattern.set_note(16, 1, Some(note.clone()));
        pattern.set_note(32, 2, Some(note));
        
        tracker.load_pattern(pattern);
        
        // Test playback timing
        let initial_row = tracker.current_row;
        tracker.advance_tick();
        
        // After 6 ticks, should advance to next row
        for _ in 0..6 {
            tracker.advance_tick();
        }
        
        assert_eq!(tracker.current_row, initial_row + 1);
    }

    #[test]
    fn test_audio_buffer_overflow_protection() {
        let mut mixer = MixingEngine::new(44100, 2);
        
        // Create channel with very high volume
        let mut channel = Channel::new();
        channel.volume = 255; // Maximum volume
        channel.play_note(60, 1, 127); // Maximum note volume
        
        mixer.add_channel(channel);
        
        // Generate audio and check for clipping protection
        let buffer = mixer.mix_audio(1024);
        
        // All samples should be within valid range [-1.0, 1.0]
        for &sample in &buffer {
            assert!(sample >= -1.0 && sample <= 1.0);
        }
    }

    #[test]
    fn test_effect_processing() {
        let mut channel = Channel::new();
        
        // Test portamento effect (slide between notes)
        let effect = Effect::Portamento { speed: 4 };
        channel.apply_effect(effect);
        
        channel.play_note(60, 1, 64); // Start note
        let initial_freq = channel.current_frequency;
        
        channel.target_note(67, 1); // Target note (G)
        
        // Process effect over several ticks
        for _ in 0..10 {
            channel.process_effects();
        }
        
        // Frequency should have changed towards target
        assert_ne!(channel.current_frequency, initial_freq);
    }

    #[test]
    fn test_sample_format_conversion() {
        // Test 8-bit to 16-bit conversion
        let samples_8bit = vec![128u8, 255, 0, 64]; // Various 8-bit values
        let samples_16bit = convert_8bit_to_16bit(&samples_8bit);
        
        assert_eq!(samples_16bit.len(), samples_8bit.len());
        
        // Test specific conversions
        assert_eq!(samples_16bit[0], 0);      // 128 -> 0 (center)
        assert_eq!(samples_16bit[1], 32767);  // 255 -> max positive
        assert_eq!(samples_16bit[2], -32768); // 0 -> max negative
    }

    #[test]
    fn test_loop_handling() {
        let mut pattern = Pattern::new(16, 2);
        pattern.set_loop_start(4);
        pattern.set_loop_end(12);
        
        let mut tracker = TrackerEngine::new();
        tracker.load_pattern(pattern);
        
        // Play through to loop end
        tracker.current_row = 12;
        tracker.advance_row();
        
        // Should jump back to loop start
        assert_eq!(tracker.current_row, 4);
    }

    #[test]
    fn test_song_arrangement() {
        let mut song = Song::new("Test Song");
        
        // Create patterns
        let pattern1 = Pattern::new(32, 4);
        let pattern2 = Pattern::new(32, 4);
        
        song.add_pattern(pattern1);
        song.add_pattern(pattern2);
        
        // Create arrangement
        song.set_pattern_order(vec![0, 1, 0, 1]); // ABAB structure
        
        assert_eq!(song.pattern_order.len(), 4);
        assert_eq!(song.get_pattern_at_position(0), Some(0));
        assert_eq!(song.get_pattern_at_position(2), Some(0)); // Repeat
    }

    #[test]
    fn test_real_time_audio_constraints() {
        let mut mixer = MixingEngine::new(44100, 2);
        
        // Add multiple channels to stress test
        for i in 0..8 {
            let mut channel = Channel::new();
            channel.play_note(60 + i as u8, 1, 64);
            mixer.add_channel(channel);
        }
        
        // Measure audio generation time
        let start = std::time::Instant::now();
        let buffer = mixer.mix_audio(1024); // ~23ms of audio at 44.1kHz
        let generation_time = start.elapsed();
        
        // Should generate faster than real-time
        assert!(generation_time < Duration::from_millis(20));
        assert_eq!(buffer.len(), 2048); // 1024 * 2 channels
    }

    #[test]
    fn test_edge_case_empty_pattern() {
        let pattern = Pattern::new(0, 0);
        
        assert_eq!(pattern.length, 0);
        assert_eq!(pattern.channels, 0);
        assert!(pattern.data.is_empty());
        
        // Should not crash on empty pattern
        assert!(pattern.get_note(0, 0).is_none());
    }

    #[test]
    fn test_edge_case_extreme_bpm() {
        let mut tracker = TrackerEngine::new();
        
        // Test very low BPM
        tracker.set_bpm(1);
        assert_eq!(tracker.bpm, 1);
        
        // Test very high BPM
        tracker.set_bpm(999);
        assert_eq!(tracker.bpm, 999);
        
        // Calculations should still work
        let samples = tracker.calculate_samples_per_tick(44100);
        assert!(samples > 0);
    }

    #[test]
    fn test_instrument_bank_management() {
        let mut bank = InstrumentBank::new();
        
        let instrument1 = Instrument::new("Piano");
        let instrument2 = Instrument::new("Guitar");
        
        bank.add_instrument(instrument1);
        bank.add_instrument(instrument2);
        
        assert_eq!(bank.get_instrument_count(), 2);
        
        let retrieved = bank.get_instrument(0).unwrap();
        assert_eq!(retrieved.name, "Piano");
        
        // Test removal
        bank.remove_instrument(1);
        assert_eq!(bank.get_instrument_count(), 1);
    }

    #[test]
    fn test_audio_export_functionality() {
        let mut tracker = TrackerEngine::new();
        
        // Create simple pattern with notes
        let mut pattern = Pattern::new(4, 1);
        pattern.set_note(0, 0, Some(Note::new(60, 4, 1, 64)));
        pattern.set_note(2, 0, Some(Note::new(64, 4, 1, 64)));
        
        tracker.load_pattern(pattern);
        
        // Export to audio buffer
        let sample_rate = 44100;
        let duration_seconds = 2.0;
        let audio_data = tracker.export_to_audio(sample_rate, duration_seconds);
        
        let expected_samples = (sample_rate as f64 * duration_seconds) as usize * 2; // Stereo
        assert_eq!(audio_data.len(), expected_samples);
        
        // Verify audio contains actual sound (not silence)
        let max_amplitude = audio_data.iter().fold(0.0f32, |acc, &x| acc.max(x.abs()));
        assert!(max_amplitude > 0.001); // Should have audible content
    }
}