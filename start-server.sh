#!/bin/bash

# Simple script to start a local web server for the demo
# This is needed to avoid CORS/tainted canvas issues with video capture

echo "🚀 Starting local web server for RH126 Demo..."
echo ""
echo "📁 Server will run from: $(pwd)"
echo ""

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    echo "✅ Using Python 3 HTTP server"
    echo ""
    echo "🌐 Open in browser:"
    echo "   - Main Demo:        http://localhost:2000/web/index.html"
    echo "   - VLM Demo:         http://localhost:2000/web/vlm.html"
    echo "   - Video Search:     http://localhost:2000/web/video-search.html"
    echo "   - Game:             http://localhost:2000/web/game.html"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    python3 -m http.server 2000
elif command -v python &> /dev/null; then
    echo "✅ Using Python 2 HTTP server"
    echo ""
    echo "🌐 Open in browser:"
    echo "   - Main Demo:        http://localhost:2000/web/index.html"
    echo "   - VLM Demo:         http://localhost:2000/web/vlm.html"
    echo "   - Video Search:     http://localhost:2000/web/video-search.html"
    echo "   - Game:             http://localhost:2000/web/game.html"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    python -m SimpleHTTPServer 2000
else
    echo "❌ Python not found!"
    echo ""
    echo "Please install Python or use an alternative:"
    echo "  - npm: npx serve . -p 2000"
    echo "  - php: php -S localhost:2000"
    echo ""
    exit 1
fi

