#!/bin/bash

# {{{ Run File Server Script
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ $# -gt 0 ]; then
    DIR="$1"
fi

INTERACTIVE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -I|--interactive)
            INTERACTIVE=true
            shift
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

cd "$DIR" || exit 1

# {{{ interactive_mode
interactive_mode() {
# }}}
    echo "🗂️ Enhanced Project File Server - Interactive Mode"
    echo "=================================================="
    echo
    echo "Select an action:"
    echo "1) Generate/Update file server HTML"
    echo "2) Start HTTP server (port 8080)"
    echo "3) Start HTTP server (custom port)"
    echo "4) Open file server in browser"
    echo "5) View file server location"
    echo "6) Exit"
    echo
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            echo "Generating file server HTML..."
            lua src/src-2/project-file-server-enhanced.lua "$DIR"
            echo "✅ File server generated!"
            ;;
        2)
            echo "Starting HTTP server on port 8080..."
            echo "📁 Serving directory: $DIR/assets/assets-2/"
            echo "🌐 Open: http://localhost:8080/enhanced-project-file-server.html"
            echo "Press Ctrl+C to stop"
            cd "$DIR/assets/assets-2" && python3 -m http.server 8080
            ;;
        3)
            read -p "Enter port number: " port
            echo "Starting HTTP server on port $port..."
            echo "📁 Serving directory: $DIR/assets/assets-2/"
            echo "🌐 Open: http://localhost:$port/enhanced-project-file-server.html"
            echo "Press Ctrl+C to stop"
            cd "$DIR/assets/assets-2" && python3 -m http.server "$port"
            ;;
        4)
            html_file="$DIR/assets/assets-2/enhanced-project-file-server.html"
            if [ -f "$html_file" ]; then
                echo "Opening file server in browser..."
                xdg-open "file://$html_file" 2>/dev/null || open "file://$html_file" 2>/dev/null || echo "Please manually open: file://$html_file"
            else
                echo "❌ File server HTML not found. Generate it first (option 1)"
            fi
            ;;
        5)
            html_file="$DIR/assets/assets-2/enhanced-project-file-server.html"
            echo "📍 File server location: $html_file"
            if [ -f "$html_file" ]; then
                echo "✅ File exists"
                stat_info=$(stat -c "Size: %s bytes, Modified: %y" "$html_file")
                echo "📊 $stat_info"
            else
                echo "❌ File not found"
            fi
            ;;
        6)
            echo "Goodbye! 👋"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please select 1-6."
            ;;
    esac
}

# {{{ main_execution
if [ "$INTERACTIVE" = true ]; then
    while true; do
        interactive_mode
        echo
        read -p "Press Enter to continue or Ctrl+C to exit..."
        echo
    done
else
    # Default: generate file server and show instructions
    echo "🗂️ Generating Enhanced Project File Server..."
    lua src/src-2/project-file-server-enhanced.lua "$DIR"
    
    html_file="$DIR/assets/assets-2/enhanced-project-file-server.html"
    echo
    echo "✅ File server generated successfully!"
    echo "📍 Location: $html_file"
    echo
    echo "🚀 To use the file server:"
    echo "   1. Open directly: file://$html_file"
    echo "   2. Or start HTTP server: $0 -I (interactive mode)"
    echo "   3. Or quick HTTP server: cd '$DIR/assets/assets-2' && python3 -m http.server 8080"
    echo
    echo "💡 Use $0 -I for interactive mode with more options"
fi
# }}}