# Quick Start Guide - Wikipedia MCP Server

## 🚀 Fast Setup (5 minutes)

### Step 1: Install Dependencies
```bash
cd /Users/cchia/projects/science_map/mcp-wikipedia-server
npm install
```

### Step 2: Configure Cursor

**Option A: Via Settings UI (Easiest)**
1. Open Cursor → Settings (`Cmd + ,`)
2. Search for "MCP"
3. Click "Add New MCP Server"
4. Fill in:
   - **Name:** `Wikipedia`
   - **Command:** `node`
   - **Args:** `/Users/cchia/projects/science_map/mcp-wikipedia-server/index.js`
5. Save and restart Cursor

**Option B: Edit Config File**
1. Open: `~/Library/Application Support/Cursor/User/globalStorage/mcp.json`
2. Add the config from `cursor-config-example.json`
3. Save and restart Cursor

### Step 3: Test It

In Cursor chat, try:
```
Get the Wikipedia summary for Archimedes
```

## 📋 Available Commands

Once connected, you can ask Cursor:

- "Search Wikipedia for Blaise Pascal"
- "Get Wikipedia summary about Isaac Newton"
- "What does Wikipedia say about quantum mechanics?"
- "Fetch detailed info about Charles's Law from Wikipedia"

## 🔧 Troubleshooting

**Server not connecting?**
- Check path is correct in Cursor settings
- Verify Node.js is installed: `node --version`
- Try running manually: `node index.js`

**No results?**
- Test API: `curl "https://en.wikipedia.org/api/rest_v1/page/summary/Test"`
- Check internet connection

## 📚 Full Documentation

See `README.md` for complete setup instructions.


