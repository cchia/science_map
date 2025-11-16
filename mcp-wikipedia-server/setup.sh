#!/bin/bash

# Wikipedia MCP Server Setup Script
# This script helps you set up the Wikipedia MCP server for Cursor

echo "🚀 Setting up Wikipedia MCP Server..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"
echo "✅ npm found: $(npm --version)"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"
echo ""

# Make script executable
chmod +x index.js
echo "✅ Made index.js executable"
echo ""

# Test Wikipedia API
echo "🧪 Testing Wikipedia API connectivity..."
curl -s "https://en.wikipedia.org/api/rest_v1/page/summary/Archimedes" > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Wikipedia API is accessible"
else
    echo "⚠️  Could not reach Wikipedia API (check internet connection)"
fi
echo ""

# Display configuration info
echo "📝 Next steps:"
echo ""
echo "1. Copy the configuration from cursor-config-example.json"
echo "2. Add it to your Cursor MCP settings:"
echo "   macOS: ~/Library/Application Support/Cursor/User/globalStorage/mcp.json"
echo "   Linux: ~/.config/cursor/mcp.json"
echo "   Windows: %APPDATA%\\Cursor\\User\\globalStorage\\mcp.json"
echo ""
echo "3. Or use Cursor's Settings UI:"
echo "   Settings → Features → MCP → Add New MCP Server"
echo ""
echo "4. Restart Cursor"
echo ""
echo "✨ Setup complete! Read README.md for detailed instructions."


