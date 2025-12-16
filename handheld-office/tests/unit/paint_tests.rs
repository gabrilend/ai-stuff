use handheld_office::*;
use std::io::Cursor;

#[cfg(test)]
mod paint_tests {
    use super::*;

    #[test]
    fn test_canvas_creation_with_valid_dimensions() {
        let canvas = Canvas::new(16, 16);
        assert_eq!(canvas.width, 16);
        assert_eq!(canvas.height, 16);
        assert_eq!(canvas.pixels.len(), 256); // 16 * 16
        
        // All pixels should be initialized to 0 (transparent/background)
        assert!(canvas.pixels.iter().all(|&pixel| pixel == 0));
    }

    #[test]
    fn test_canvas_pixel_setting_bounds_checking() {
        let mut canvas = Canvas::new(8, 8);
        
        // Valid pixel setting
        canvas.set_pixel(3, 3, 1);
        assert_eq!(canvas.get_pixel(3, 3), 1);
        
        // Boundary testing
        canvas.set_pixel(0, 0, 2);
        assert_eq!(canvas.get_pixel(0, 0), 2);
        
        canvas.set_pixel(7, 7, 3);
        assert_eq!(canvas.get_pixel(7, 7), 3);
        
        // Out of bounds should not panic but return default
        assert_eq!(canvas.get_pixel(8, 8), 0);
        assert_eq!(canvas.get_pixel(100, 100), 0);
    }

    #[test]
    fn test_canvas_clear_operation() {
        let mut canvas = Canvas::new(4, 4);
        
        // Set some pixels
        canvas.set_pixel(1, 1, 5);
        canvas.set_pixel(2, 2, 10);
        canvas.set_pixel(3, 3, 15);
        
        // Clear canvas
        canvas.clear();
        
        // All pixels should be 0
        assert!(canvas.pixels.iter().all(|&pixel| pixel == 0));
    }

    #[test]
    fn test_line_drawing_algorithm_accuracy() {
        let mut canvas = Canvas::new(10, 10);
        
        // Test horizontal line
        canvas.draw_line(1, 5, 8, 5, 1);
        for x in 1..=8 {
            assert_eq!(canvas.get_pixel(x, 5), 1);
        }
        
        // Test vertical line
        canvas.clear();
        canvas.draw_line(5, 1, 5, 8, 2);
        for y in 1..=8 {
            assert_eq!(canvas.get_pixel(5, y), 2);
        }
        
        // Test diagonal line (Bresenham algorithm)
        canvas.clear();
        canvas.draw_line(0, 0, 3, 3, 3);
        assert_eq!(canvas.get_pixel(0, 0), 3);
        assert_eq!(canvas.get_pixel(1, 1), 3);
        assert_eq!(canvas.get_pixel(2, 2), 3);
        assert_eq!(canvas.get_pixel(3, 3), 3);
    }

    #[test]
    fn test_flood_fill_boundary_detection() {
        let mut canvas = Canvas::new(6, 6);
        
        // Create a 3x3 square outline
        for i in 1..=3 {
            canvas.set_pixel(i, 1, 1); // Top
            canvas.set_pixel(i, 3, 1); // Bottom
            canvas.set_pixel(1, i, 1); // Left
            canvas.set_pixel(3, i, 1); // Right
        }
        
        // Fill the inside
        canvas.flood_fill(2, 2, 5);
        
        // Check that only the inside pixel was filled
        assert_eq!(canvas.get_pixel(2, 2), 5);
        
        // Check that boundaries remain unchanged
        assert_eq!(canvas.get_pixel(1, 1), 1);
        assert_eq!(canvas.get_pixel(3, 3), 1);
        
        // Check that outside area is unchanged
        assert_eq!(canvas.get_pixel(0, 0), 0);
        assert_eq!(canvas.get_pixel(5, 5), 0);
    }

    #[test]
    fn test_palette_color_indexing() {
        let palette = Palette::default_gameboy();
        
        // GameBoy palette should have 4 colors
        assert_eq!(palette.colors.len(), 4);
        
        // Test specific GameBoy colors
        assert_eq!(palette.colors[0], (0x0F, 0x38, 0x0F)); // Dark green
        assert_eq!(palette.colors[3], (0x9B, 0xBC, 0x0F)); // Light green
    }

    #[test]
    fn test_palette_serialization() {
        let original_palette = Palette::default_gameboy();
        
        // Serialize to JSON
        let serialized = serde_json::to_string(&original_palette).expect("Serialization failed");
        
        // Deserialize back
        let deserialized: Palette = serde_json::from_str(&serialized).expect("Deserialization failed");
        
        // Should be identical
        assert_eq!(original_palette.colors, deserialized.colors);
    }

    #[test]
    fn test_brush_tool_pixel_placement() {
        let mut canvas = Canvas::new(10, 10);
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        
        // Set brush tool
        paint_app.current_tool = DrawingTool::Brush;
        paint_app.current_color = 3;
        
        // Simulate brush stroke
        paint_app.start_drawing(5, 5);
        paint_app.continue_drawing(6, 5);
        paint_app.continue_drawing(7, 5);
        paint_app.stop_drawing();
        
        // Check that pixels were painted
        assert_eq!(paint_app.canvas.get_pixel(5, 5), 3);
        assert_eq!(paint_app.canvas.get_pixel(6, 5), 3);
        assert_eq!(paint_app.canvas.get_pixel(7, 5), 3);
    }

    #[test]
    fn test_circle_drawing_algorithm() {
        let mut canvas = Canvas::new(20, 20);
        
        // Draw circle with radius 5 at center (10, 10)
        canvas.draw_circle(10, 10, 5, 2);
        
        // Test some points on the circle
        assert_eq!(canvas.get_pixel(15, 10), 2); // Right
        assert_eq!(canvas.get_pixel(5, 10), 2);  // Left
        assert_eq!(canvas.get_pixel(10, 15), 2); // Bottom
        assert_eq!(canvas.get_pixel(10, 5), 2);  // Top
        
        // Test points inside circle are not filled (outline only)
        assert_eq!(canvas.get_pixel(10, 10), 0); // Center should be empty
    }

    #[test]
    fn test_canvas_resize_operations() {
        let mut canvas = Canvas::new(4, 4);
        
        // Set some pixels
        canvas.set_pixel(1, 1, 5);
        canvas.set_pixel(2, 2, 10);
        
        // Resize to larger
        canvas.resize(8, 8);
        assert_eq!(canvas.width, 8);
        assert_eq!(canvas.height, 8);
        assert_eq!(canvas.pixels.len(), 64);
        
        // Original pixels should be preserved
        assert_eq!(canvas.get_pixel(1, 1), 5);
        assert_eq!(canvas.get_pixel(2, 2), 10);
        
        // New areas should be initialized to 0
        assert_eq!(canvas.get_pixel(7, 7), 0);
    }

    #[test]
    fn test_undo_redo_stack_operations() {
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        
        // Initial state
        let initial_canvas = paint_app.canvas.clone();
        
        // Make a change
        paint_app.canvas.set_pixel(5, 5, 3);
        paint_app.save_state_for_undo();
        
        // Make another change
        paint_app.canvas.set_pixel(6, 6, 4);
        paint_app.save_state_for_undo();
        
        // Undo once
        paint_app.undo();
        assert_eq!(paint_app.canvas.get_pixel(6, 6), 0);
        assert_eq!(paint_app.canvas.get_pixel(5, 5), 3);
        
        // Undo again
        paint_app.undo();
        assert_eq!(paint_app.canvas.get_pixel(5, 5), 0);
        
        // Redo
        paint_app.redo();
        assert_eq!(paint_app.canvas.get_pixel(5, 5), 3);
    }

    #[test]
    fn test_paint_to_ascii_conversion() {
        let mut canvas = Canvas::new(4, 4);
        
        // Create a simple pattern
        canvas.set_pixel(0, 0, 1);
        canvas.set_pixel(1, 1, 2);
        canvas.set_pixel(2, 2, 3);
        canvas.set_pixel(3, 3, 1);
        
        let ascii_art = canvas.to_ascii_art();
        
        // Should contain ASCII representation
        assert!(!ascii_art.is_empty());
        assert!(ascii_art.contains('\n')); // Should have line breaks
        assert!(ascii_art.lines().count() == 4); // Should have 4 lines
    }

    #[test]
    fn test_edge_case_small_canvas() {
        // Test 1x1 canvas
        let mut canvas = Canvas::new(1, 1);
        canvas.set_pixel(0, 0, 5);
        assert_eq!(canvas.get_pixel(0, 0), 5);
        
        // Test flood fill on 1x1
        canvas.flood_fill(0, 0, 10);
        assert_eq!(canvas.get_pixel(0, 0), 10);
    }

    #[test]
    fn test_edge_case_drawing_outside_bounds() {
        let mut canvas = Canvas::new(5, 5);
        
        // Line extending outside bounds
        canvas.draw_line(3, 3, 10, 10, 1);
        
        // Should only draw the portion within bounds
        assert_eq!(canvas.get_pixel(3, 3), 1);
        assert_eq!(canvas.get_pixel(4, 4), 1);
        
        // Outside bounds should remain 0
        assert_eq!(canvas.get_pixel(10, 10), 0);
    }

    #[test]
    fn test_flood_fill_fully_connected_canvas() {
        let mut canvas = Canvas::new(3, 3);
        
        // Fill entire canvas with same color
        canvas.flood_fill(1, 1, 7);
        
        // All pixels should be filled
        for y in 0..3 {
            for x in 0..3 {
                assert_eq!(canvas.get_pixel(x, y), 7);
            }
        }
    }

    #[test]
    fn test_color_conversion_rgb_to_index() {
        let palette = Palette::default_gameboy();
        
        // Test finding closest color in palette
        let closest_index = palette.find_closest_color(0x0F, 0x38, 0x0F);
        assert_eq!(closest_index, 0); // Should match first GameBoy color
        
        let closest_index = palette.find_closest_color(0x9B, 0xBC, 0x0F);
        assert_eq!(closest_index, 3); // Should match last GameBoy color
    }

    #[test]
    fn test_save_load_operations() {
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        
        // Create some art
        paint_app.canvas.set_pixel(2, 2, 5);
        paint_app.canvas.set_pixel(3, 3, 10);
        
        // Save to temporary file
        let temp_file = tempfile::NamedTempFile::new().expect("Failed to create temp file");
        let file_path = temp_file.path();
        
        paint_app.save_artwork(file_path).expect("Failed to save artwork");
        
        // Load from file
        let mut loaded_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        loaded_app.load_artwork(file_path).expect("Failed to load artwork");
        
        // Should match original
        assert_eq!(loaded_app.canvas.get_pixel(2, 2), 5);
        assert_eq!(loaded_app.canvas.get_pixel(3, 3), 10);
    }

    #[test]
    fn test_radial_menu_navigation() {
        let mut paint_app = AnbernicPaintApp::new().expect("Failed to create paint app");
        
        // Test navigation through tools
        let initial_tool = paint_app.current_tool.clone();
        
        // Navigate right (next tool)
        paint_app.handle_input(RadialButton::R).expect("Failed to handle input");
        assert_ne!(paint_app.current_tool, initial_tool);
        
        // Navigate left (previous tool)
        paint_app.handle_input(RadialButton::L).expect("Failed to handle input");
        assert_eq!(paint_app.current_tool, initial_tool);
    }
}