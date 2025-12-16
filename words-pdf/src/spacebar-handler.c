// {{{ WebAssembly Spacebar Handler
// Secure spacebar detection without JavaScript vulnerabilities
#include <emscripten.h>
#include <emscripten/html5.h>
#include <stdio.h>
#include <string.h>

// Global state for expansion mode
static int expansion_mode = 0;
static char current_context[8192] = {0};
static char response_lines[16384] = {0};

// {{{ Forward declarations
void display_expanding_response();
void generate_next_line();
// }}}

// {{{ Exported functions callable from HTML
EMSCRIPTEN_KEEPALIVE
void enter_expansion_mode(const char* initial_response, const char* context) {
    expansion_mode = 1;
    strncpy(current_context, context, sizeof(current_context) - 1);
    strncpy(response_lines, initial_response, sizeof(response_lines) - 1);
    
    // Hide input elements, show expansion UI
    EM_ASM({
        document.getElementById('expansionMode').style.display = 'block';
        document.getElementById('userInput').style.display = 'none';
        document.querySelector('input[type="submit"]').style.display = 'none';
    });
    
    display_expanding_response();
}

EMSCRIPTEN_KEEPALIVE
void exit_expansion_mode() {
    expansion_mode = 0;
    memset(current_context, 0, sizeof(current_context));
    memset(response_lines, 0, sizeof(response_lines));
    
    // Show input elements, hide expansion UI
    EM_ASM({
        document.getElementById('expansionMode').style.display = 'none';
        document.getElementById('userInput').style.display = 'inline';
        document.querySelector('input[type="submit"]').style.display = 'inline';
        document.getElementById('userInput').focus();
    });
}

EMSCRIPTEN_KEEPALIVE
int is_expansion_mode() {
    return expansion_mode;
}
// }}}

// {{{ Internal functions
void display_expanding_response() {
    EM_ASM_({
        const responseDiv = document.getElementById('expandingResponse');
        responseDiv.textContent = UTF8ToString($0);
    }, response_lines);
}

void generate_next_line() {
    // Make HTTP request for next line expansion
    EM_ASM_({
        const accumulatedLines = UTF8ToString($0);
        const context = UTF8ToString($1);
        
        fetch('/expand-line', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'accumulated=' + encodeURIComponent(accumulatedLines) + 
                  '&context=' + encodeURIComponent(context)
        })
        .then(response => response.text())
        .then(newLine => {
            // Update response_lines via WASM
            const combined = accumulatedLines + '\n' + newLine;
            Module.ccall('update_response_lines', null, ['string'], [combined]);
        });
    }, response_lines, current_context);
}

EMSCRIPTEN_KEEPALIVE
void update_response_lines(const char* new_lines) {
    strncpy(response_lines, new_lines, sizeof(response_lines) - 1);
    display_expanding_response();
}
// }}}

// {{{ Keyboard event handler
EM_BOOL keydown_callback(int eventType, const EmscriptenKeyboardEvent *e, void *userData) {
    if (expansion_mode) {
        // Check for spacebar (keyCode 32, key "Space")
        if (strcmp(e->code, "Space") == 0) {
            generate_next_line();
            return EM_TRUE; // Prevent default behavior
        }
        // Any other key exits expansion mode
        else {
            exit_expansion_mode();
            return EM_FALSE; // Allow normal key handling
        }
    }
    return EM_FALSE; // Don't handle if not in expansion mode
}

EMSCRIPTEN_KEEPALIVE
void init_keyboard_handler() {
    emscripten_set_keydown_callback(EMSCRIPTEN_EVENT_TARGET_DOCUMENT, 0, 1, keydown_callback);
}
// }}}

// {{{ Module initialization
EMSCRIPTEN_KEEPALIVE
void wasm_init() {
    init_keyboard_handler();
    printf("WebAssembly spacebar handler initialized securely\n");
}
// }}}