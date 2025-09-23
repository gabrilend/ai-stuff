use handheld_office::*;
use handheld_office::terminal::*;
use std::path::PathBuf;
use tempfile::TempDir;

#[cfg(test)]
mod terminal_tests {
    use super::*;

    #[test]
    fn test_terminal_creation_and_initialization() {
        let terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        assert!(terminal.current_directory.exists());
        assert_eq!(terminal.command_history.len(), 0);
        assert_eq!(terminal.input_state.selected_index, 0);
        assert_eq!(terminal.ui_state.current_view, TerminalView::MainMenu);
    }

    #[test]
    fn test_directory_navigation_bounds() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        let original_dir = terminal.current_directory.clone();
        
        // Try to navigate to a valid directory
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let temp_path = temp_dir.path().to_path_buf();
        
        let result = terminal.change_directory(&temp_path);
        assert!(result.is_ok());
        assert_eq!(terminal.current_directory, temp_path);
        
        // Navigate back
        let result = terminal.change_directory(&original_dir);
        assert!(result.is_ok());
        assert_eq!(terminal.current_directory, original_dir);
    }

    #[test]
    fn test_directory_navigation_invalid_path() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        let original_dir = terminal.current_directory.clone();
        let invalid_path = PathBuf::from("/this/path/definitely/does/not/exist");
        
        let result = terminal.change_directory(&invalid_path);
        assert!(result.is_err());
        
        // Directory should remain unchanged
        assert_eq!(terminal.current_directory, original_dir);
    }

    #[test]
    fn test_filesystem_cache_updates() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Create temporary directory with files
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        std::fs::write(temp_dir.path().join("test1.txt"), "content1").expect("Failed to write file");
        std::fs::write(temp_dir.path().join("test2.txt"), "content2").expect("Failed to write file");
        std::fs::create_dir(temp_dir.path().join("subdir")).expect("Failed to create subdir");
        
        // Navigate to temp directory
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // Cache should be populated
        assert!(terminal.filesystem_cache.current_entries.len() >= 3); // At least our created items
        
        let has_test1 = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "test1.txt");
        let has_test2 = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "test2.txt");
        let has_subdir = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "subdir" && entry.entry_type == EntryType::Directory);
        
        assert!(has_test1);
        assert!(has_test2);
        assert!(has_subdir);
    }

    #[test]
    fn test_file_permissions_handling() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Create temp file with specific permissions
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let file_path = temp_dir.path().join("readonly.txt");
        std::fs::write(&file_path, "content").expect("Failed to write file");
        
        // Set readonly permissions
        let mut perms = std::fs::metadata(&file_path).expect("Failed to get metadata").permissions();
        perms.set_readonly(true);
        std::fs::set_permissions(&file_path, perms).expect("Failed to set permissions");
        
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // Find the file in cache
        let file_entry = terminal.filesystem_cache.current_entries.iter()
            .find(|entry| entry.name == "readonly.txt")
            .expect("File not found in cache");
        
        assert_eq!(file_entry.entry_type, EntryType::File);
        // Should detect readonly permission
        assert!(!file_entry.permissions.writable);
    }

    #[test]
    fn test_command_builder_flag_validation() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Switch to command builder
        terminal.ui_state.current_view = TerminalView::CommandBuilder;
        terminal.command_builder.base_command = "ls".to_string();
        
        // Add valid flags
        terminal.command_builder.add_flag("-l".to_string());
        terminal.command_builder.add_flag("-a".to_string());
        
        assert!(terminal.command_builder.flags.contains(&"-l".to_string()));
        assert!(terminal.command_builder.flags.contains(&"-a".to_string()));
        
        // Test flag removal
        terminal.command_builder.remove_flag(&"-l".to_string());
        assert!(!terminal.command_builder.flags.contains(&"-l".to_string()));
        assert!(terminal.command_builder.flags.contains(&"-a".to_string()));
    }

    #[test]
    fn test_command_history_persistence() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Execute some commands
        let cmd1 = CommandEntry {
            command: "ls -la".to_string(),
            directory: terminal.current_directory.clone(),
            timestamp: chrono::Utc::now(),
            exit_code: 0,
            output: "file1.txt\nfile2.txt".to_string(),
        };
        
        let cmd2 = CommandEntry {
            command: "pwd".to_string(),
            directory: terminal.current_directory.clone(),
            timestamp: chrono::Utc::now(),
            exit_code: 0,
            output: terminal.current_directory.to_string_lossy().to_string(),
        };
        
        terminal.command_history.push(cmd1.clone());
        terminal.command_history.push(cmd2.clone());
        
        assert_eq!(terminal.command_history.len(), 2);
        assert_eq!(terminal.command_history[0].command, "ls -la");
        assert_eq!(terminal.command_history[1].command, "pwd");
        
        // Test history navigation
        let latest_command = terminal.get_latest_command();
        assert_eq!(latest_command.unwrap().command, "pwd");
    }

    #[test]
    fn test_working_directory_management() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        let original_dir = terminal.current_directory.clone();
        
        // Create nested directory structure
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let subdir = temp_dir.path().join("level1").join("level2");
        std::fs::create_dir_all(&subdir).expect("Failed to create nested dirs");
        
        // Navigate deeper
        terminal.change_directory(&temp_dir.path().join("level1")).expect("Failed to navigate");
        terminal.change_directory(&subdir).expect("Failed to navigate deeper");
        
        assert_eq!(terminal.current_directory, subdir);
        
        // Test parent directory tracking
        assert!(terminal.filesystem_cache.parent_directory.is_some());
        let parent = terminal.filesystem_cache.parent_directory.as_ref().unwrap();
        assert_eq!(*parent, temp_dir.path().join("level1"));
    }

    #[test]
    fn test_radial_keyboard_character_mapping() {
        let keyboard = RadialKeyboard::new();
        
        // Test sector navigation
        assert_eq!(keyboard.current_sector, 0);
        assert_eq!(keyboard.current_char_index, 0);
        
        // Test character retrieval from sectors
        let char_a = keyboard.get_current_character();
        assert!(char_a.is_some());
        
        // Navigate through sectors
        let mut kb = keyboard;
        kb.next_sector();
        assert_eq!(kb.current_sector, 1);
        
        kb.previous_sector();
        assert_eq!(kb.current_sector, 0);
    }

    #[test]
    fn test_text_buffer_management() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Switch to text input mode
        terminal.input_state.input_mode = InputMode::TextInput;
        terminal.input_state.text_buffer = String::new();
        
        // Simulate typing
        terminal.input_state.text_buffer.push('H');
        terminal.input_state.text_buffer.push('e');
        terminal.input_state.text_buffer.push('l');
        terminal.input_state.text_buffer.push('l');
        terminal.input_state.text_buffer.push('o');
        
        assert_eq!(terminal.input_state.text_buffer, "Hello");
        
        // Test backspace
        terminal.input_state.text_buffer.pop();
        assert_eq!(terminal.input_state.text_buffer, "Hell");
        
        // Test clear
        terminal.input_state.text_buffer.clear();
        assert_eq!(terminal.input_state.text_buffer, "");
    }

    #[test]
    fn test_input_mode_transitions() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Start in navigation mode
        assert_eq!(terminal.input_state.input_mode, InputMode::Navigation);
        
        // Switch to command builder
        terminal.ui_state.current_view = TerminalView::CommandBuilder;
        terminal.command_builder.build_state = BuildState::EnteringParameters;
        terminal.input_state.input_mode = InputMode::TextInput;
        
        assert_eq!(terminal.input_state.input_mode, InputMode::TextInput);
        assert_eq!(terminal.command_builder.build_state, BuildState::EnteringParameters);
        
        // Return to navigation
        terminal.input_state.input_mode = InputMode::Navigation;
        terminal.command_builder.build_state = BuildState::SelectingCommand;
        
        assert_eq!(terminal.input_state.input_mode, InputMode::Navigation);
    }

    #[test]
    fn test_hidden_file_filtering() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Create temp directory with hidden and visible files
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        std::fs::write(temp_dir.path().join("visible.txt"), "content").expect("Failed to write file");
        std::fs::write(temp_dir.path().join(".hidden"), "hidden content").expect("Failed to write hidden file");
        std::fs::write(temp_dir.path().join(".config"), "config content").expect("Failed to write config file");
        
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // By default, hidden files should be filtered
        let visible_entries: Vec<_> = terminal.filesystem_cache.current_entries.iter()
            .filter(|entry| !entry.name.starts_with('.'))
            .collect();
        
        let hidden_entries: Vec<_> = terminal.filesystem_cache.current_entries.iter()
            .filter(|entry| entry.name.starts_with('.'))
            .collect();
        
        assert!(visible_entries.len() >= 1); // At least visible.txt
        
        // Toggle show hidden files
        terminal.filesystem_cache.show_hidden = true;
        terminal.refresh_filesystem_cache().expect("Failed to refresh cache");
        
        let total_entries = terminal.filesystem_cache.current_entries.len();
        assert!(total_entries >= 3); // visible.txt + .hidden + .config (plus potentially . and ..)
    }

    #[test]
    fn test_command_execution_output_capture() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Build a simple command
        terminal.command_builder.base_command = "echo".to_string();
        terminal.command_builder.parameters.insert("message".to_string(), "Hello World".to_string());
        
        let command_string = terminal.command_builder.build_command_string();
        assert!(command_string.contains("echo"));
        assert!(command_string.contains("Hello World"));
    }

    #[test]
    fn test_render_output_consistency() {
        let terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Render main menu
        let output1 = terminal.render();
        let output2 = terminal.render();
        
        // Same state should produce same output
        assert_eq!(output1, output2);
        
        // Output should contain expected elements
        assert!(output1.contains("ANBERNIC TERMINAL"));
        assert!(output1.contains("File Explorer"));
        assert!(output1.contains("Command Builder"));
        assert!(output1.len() > 100); // Should be substantial output
    }

    #[test]
    fn test_input_handling_navigation() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        let initial_index = terminal.input_state.selected_index;
        
        // Navigate down
        terminal.handle_input(RadialButton::B).expect("Failed to handle input");
        assert_eq!(terminal.input_state.selected_index, initial_index + 1);
        
        // Navigate up
        terminal.handle_input(RadialButton::A).expect("Failed to handle input");
        assert_eq!(terminal.input_state.selected_index, initial_index);
    }

    #[test]
    fn test_edge_case_very_long_output() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Create command with very long output
        let long_output = "x".repeat(10000);
        let cmd = CommandEntry {
            command: "test_long_output".to_string(),
            directory: terminal.current_directory.clone(),
            timestamp: chrono::Utc::now(),
            exit_code: 0,
            output: long_output.clone(),
        };
        
        terminal.command_history.push(cmd);
        
        // Switch to history view
        terminal.ui_state.current_view = TerminalView::History;
        
        // Should handle long output without crashing
        let rendered = terminal.render();
        assert!(!rendered.is_empty());
    }

    #[test]
    fn test_edge_case_empty_directory() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Create empty directory
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        // Should handle empty directory gracefully
        let visible_entries: Vec<_> = terminal.filesystem_cache.current_entries.iter()
            .filter(|entry| !entry.name.starts_with('.'))
            .collect();
        
        // Might be empty or contain only . and ..
        assert!(visible_entries.len() <= 2);
        
        // Should still render without crashing
        let output = terminal.render();
        assert!(!output.is_empty());
    }

    #[test]
    fn test_command_timeout_handling() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // This is a mock test since actual command execution would require more setup
        let cmd = CommandEntry {
            command: "sleep 10".to_string(),
            directory: terminal.current_directory.clone(),
            timestamp: chrono::Utc::now(),
            exit_code: 124, // Timeout exit code
            output: "Command timed out".to_string(),
        };
        
        terminal.command_history.push(cmd);
        
        let latest = terminal.get_latest_command().unwrap();
        assert_eq!(latest.exit_code, 124);
        assert!(latest.output.contains("timeout"));
    }

    #[test]
    fn test_filesystem_cache_invalidation() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        terminal.change_directory(temp_dir.path()).expect("Failed to change directory");
        
        let initial_count = terminal.filesystem_cache.current_entries.len();
        
        // Add a new file to the directory
        std::fs::write(temp_dir.path().join("new_file.txt"), "content").expect("Failed to write file");
        
        // Cache should be outdated now
        terminal.refresh_filesystem_cache().expect("Failed to refresh cache");
        
        let new_count = terminal.filesystem_cache.current_entries.len();
        assert!(new_count > initial_count);
        
        let has_new_file = terminal.filesystem_cache.current_entries.iter()
            .any(|entry| entry.name == "new_file.txt");
        assert!(has_new_file);
    }

    #[test]
    fn test_terminal_state_consistency() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Perform various operations
        terminal.handle_input(RadialButton::R).expect("Failed to handle input"); // Enter file explorer
        terminal.handle_input(RadialButton::L).expect("Failed to handle input"); // Go back
        terminal.handle_input(RadialButton::B).expect("Failed to handle input"); // Navigate down
        terminal.handle_input(RadialButton::R).expect("Failed to handle input"); // Enter again
        
        // State should remain consistent
        assert!(terminal.input_state.selected_index < 10); // Reasonable bounds
        assert!(matches!(terminal.ui_state.current_view, 
            TerminalView::MainMenu | TerminalView::FilesystemBrowser | 
            TerminalView::CommandBuilder | TerminalView::History | 
            TerminalView::Settings));
    }

    #[test]
    fn test_memory_usage_with_large_history() {
        let mut terminal = AnbernicTerminal::new().expect("Failed to create terminal");
        
        // Add many commands to history
        for i in 0..1000 {
            let cmd = CommandEntry {
                command: format!("command_{}", i),
                directory: terminal.current_directory.clone(),
                timestamp: chrono::Utc::now(),
                exit_code: 0,
                output: format!("output_{}", i),
            };
            terminal.command_history.push(cmd);
        }
        
        assert_eq!(terminal.command_history.len(), 1000);
        
        // Should still render efficiently
        let start = std::time::Instant::now();
        let _output = terminal.render();
        let render_time = start.elapsed();
        
        // Should render in reasonable time even with large history
        assert!(render_time.as_millis() < 100);
    }
}