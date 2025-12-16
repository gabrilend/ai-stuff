/*
 * GBA Input Handling System
 * 8-directional movement with button state tracking
 */

#include "gba_hardware.h"
#include "input.h"

// Input state variables
static uint16_t current_keys = 0;
static uint16_t previous_keys = 0;

// Movement state (for 8-directional movement)
static uint8_t move_up = 0;
static uint8_t move_down = 0;
static uint8_t move_left = 0;
static uint8_t move_right = 0;

// Button state (for action buttons)
static uint8_t button_a = 0;
static uint8_t button_b = 0;
static uint8_t button_select = 0;
static uint8_t button_start = 0;
static uint8_t button_l = 0;
static uint8_t button_r = 0;

void input_init(void) {
    current_keys = 0;
    previous_keys = 0;
    
    // Clear movement flags
    move_up = 0;
    move_down = 0;
    move_left = 0;
    move_right = 0;
    
    // Clear button flags
    button_a = 0;
    button_b = 0;
    button_select = 0;
    button_start = 0;
    button_l = 0;
    button_r = 0;
}

void input_update(void) {
    // Store previous frame's input
    previous_keys = current_keys;
    
    // Read current input (note: GBA keys are inverted - 0 = pressed)
    current_keys = ~REG_KEYINPUT & KEY_MASK;
    
    // Process directional movement
    input_process_movement();
    
    // Process action buttons
    input_process_buttons();
}

void input_process_movement(void) {
    // Clear movement flags
    move_up = 0;
    move_down = 0;
    move_left = 0;
    move_right = 0;
    
    // Check D-pad directions
    if (current_keys & KEY_UP) {
        move_up = 1;
    }
    if (current_keys & KEY_DOWN) {
        move_down = 1;
    }
    if (current_keys & KEY_LEFT) {
        move_left = 1;
    }
    if (current_keys & KEY_RIGHT) {
        move_right = 1;
    }
}

void input_process_buttons(void) {
    // Clear button flags
    button_a = 0;
    button_b = 0;
    button_select = 0;
    button_start = 0;
    button_l = 0;
    button_r = 0;
    
    // Check action buttons
    if (current_keys & KEY_A) {
        button_a = 1;
    }
    if (current_keys & KEY_B) {
        button_b = 1;
    }
    if (current_keys & KEY_SELECT) {
        button_select = 1;
    }
    if (current_keys & KEY_START) {
        button_start = 1;
    }
    if (current_keys & KEY_L) {
        button_l = 1;
    }
    if (current_keys & KEY_R) {
        button_r = 1;
    }
}

// Movement state getters
uint8_t input_is_up(void) {
    return move_up;
}

uint8_t input_is_down(void) {
    return move_down;
}

uint8_t input_is_left(void) {
    return move_left;
}

uint8_t input_is_right(void) {
    return move_right;
}

// Button state getters
uint8_t input_is_a(void) {
    return button_a;
}

uint8_t input_is_b(void) {
    return button_b;
}

uint8_t input_is_select(void) {
    return button_select;
}

uint8_t input_is_start(void) {
    return button_start;
}

uint8_t input_is_l(void) {
    return button_l;
}

uint8_t input_is_r(void) {
    return button_r;
}

// Button press detection (just pressed this frame)
uint8_t input_pressed_a(void) {
    return (current_keys & KEY_A) && !(previous_keys & KEY_A);
}

uint8_t input_pressed_b(void) {
    return (current_keys & KEY_B) && !(previous_keys & KEY_B);
}

uint8_t input_pressed_select(void) {
    return (current_keys & KEY_SELECT) && !(previous_keys & KEY_SELECT);
}

uint8_t input_pressed_start(void) {
    return (current_keys & KEY_START) && !(previous_keys & KEY_START);
}

uint8_t input_pressed_l(void) {
    return (current_keys & KEY_L) && !(previous_keys & KEY_L);
}

uint8_t input_pressed_r(void) {
    return (current_keys & KEY_R) && !(previous_keys & KEY_R);
}

// Button release detection (just released this frame)
uint8_t input_released_a(void) {
    return !(current_keys & KEY_A) && (previous_keys & KEY_A);
}

uint8_t input_released_b(void) {
    return !(current_keys & KEY_B) && (previous_keys & KEY_B);
}

uint8_t input_released_select(void) {
    return !(current_keys & KEY_SELECT) && (previous_keys & KEY_SELECT);
}

uint8_t input_released_start(void) {
    return !(current_keys & KEY_START) && (previous_keys & KEY_START);
}

uint8_t input_released_l(void) {
    return !(current_keys & KEY_L) && (previous_keys & KEY_L);
}

uint8_t input_released_r(void) {
    return !(current_keys & KEY_R) && (previous_keys & KEY_R);
}

// Get raw key states
uint16_t input_get_keys_held(void) {
    return current_keys;
}

uint16_t input_get_keys_pressed(void) {
    return current_keys & ~previous_keys;
}

uint16_t input_get_keys_released(void) {
    return previous_keys & ~current_keys;
}

// 8-directional movement helpers
uint8_t input_is_diagonal(void) {
    return (move_up || move_down) && (move_left || move_right);
}

int8_t input_get_direction_x(void) {
    if (move_right && !move_left) return 1;
    if (move_left && !move_right) return -1;
    return 0;
}

int8_t input_get_direction_y(void) {
    if (move_down && !move_up) return 1;
    if (move_up && !move_down) return -1;
    return 0;
}

// Get direction as an 8-way enum (0-7, or -1 for no movement)
int8_t input_get_direction_8way(void) {
    int8_t x = input_get_direction_x();
    int8_t y = input_get_direction_y();
    
    if (x == 0 && y == 0) return -1;  // No movement
    
    // Convert to 8-way direction (0 = up, 1 = up-right, 2 = right, etc.)
    if (y == -1) {      // Up
        if (x == -1) return 7;      // Up-left
        if (x == 0) return 0;       // Up
        if (x == 1) return 1;       // Up-right
    }
    if (y == 0) {       // Horizontal
        if (x == -1) return 6;      // Left
        if (x == 1) return 2;       // Right
    }
    if (y == 1) {       // Down
        if (x == -1) return 5;      // Down-left
        if (x == 0) return 4;       // Down
        if (x == 1) return 3;       // Down-right
    }
    
    return -1;  // Should never reach here
}