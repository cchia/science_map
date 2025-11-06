# Step-by-Step Setup: Wikipedia MCP Server for Cursor

Follow these steps in order to set up your Wikipedia MCP server.

## ✅ Step 1: Verify Prerequisites

```bash
# Check Node.js version (must be 18 or higher)
node --version

# Check npm
npm --version
```

**If Node.js is not installed:**
- Download from: https://nodejs.org/
- Install version 18 or higher

## ✅ Step 2: Navigate to Server Directory

```bash
cd /Users/cchia/projects/science_map/mcp-wikipedia-server
```

## ✅ Step 3: Install Dependencies

```bash
npm install
```

**Expected output:**
```
added 15 packages in 2s
```

**If you see errors:**
- Make sure you're in the correct directory
- Check your internet connection
- Try: `npm install --force`

## ✅ Step 4: Test the Server (Optional but Recommended)

```bash
# Test Wikipedia API connectivity
curl "https://en.wikipedia.org/api/rest_v1/page/summary/Archimedes"
```

You should see JSON data. Press `Ctrl+C` to stop if it hangs.

```bash
# Test server startup (it will wait for input)
node index.js
```

Press `Ctrl+C` to stop. If you see errors, check the troubleshooting section.

## ✅ Step 5: Configure Cursor

### Method A: Using Cursor Settings UI (Recommended for First-Time Setup)

1. **Open Cursor**
2. **Open Settings:**
   - Press `Cmd + ,` (macOS) or `Ctrl + ,` (Windows/Linux)
   - Or: `Cursor` → `Settings` (macOS) / `File` → `Preferences` (Windows/Linux)

3. **Find MCP Settings:**
   - In the search bar at the top, type: `MCP`
   - Look for: `Features: MCP`, `Model Context Protocol`, or `MCP Servers`
   - **If you can't find it in the UI**, skip to Method B below (Direct File Configuration)

4. **Add New Server:**
   - Click the `+` button or `Add New MCP Server`
   - Fill in the form:
     - **Name:** `Wikipedia`
     - **Transport:** `stdio` (should be default)
     - **Command:** `node`
     - **Arguments:** 
       ```
       /Users/cchia/projects/science_map/mcp-wikipedia-server/index.js
       ```
     - **Environment Variables (optional - click to expand):**
       - `WIKI_API_URL`: `https://en.wikipedia.org/api/rest_v1`
       - `WIKI_LANG`: `en`

5. **Save:**
   - Click `Save` or `Apply`
   - You may see a notification that Cursor needs to restart

### Method B: Edit Configuration File Directly

1. **Locate the MCP config file:**

   **macOS:**
   ```bash
   open ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json
   ```
   
   Or manually:
   ```
   ~/Library/Application Support/Cursor/User/globalStorage/mcp.json
   ```

   **Linux:**
   ```bash
   nano ~/.config/cursor/mcp.json
   ```

   **Windows:**
   ```
   %APPDATA%\Cursor\User\globalStorage\mcp.json
   ```

2. **Create or edit the file:**

   If the file doesn't exist, create it with this content:
   ```json
   {
     "mcpServers": {
       "wikipedia": {
         "command": "node",
         "args": [
           "/Users/cchia/projects/science_map/mcp-wikipedia-server/index.js"
         ],
         "env": {
           "WIKI_API_URL": "https://en.wikipedia.org/api/rest_v1",
           "WIKI_LANG": "en"
         }
       }
     }
   }
   ```

   If the file exists, add the `"wikipedia"` entry to the `"mcpServers"` object.

3. **Save the file**

## ✅ Step 6: Restart Cursor

**Important:** After configuring MCP, you must restart Cursor for the changes to take effect.

1. **Quit Cursor completely:**
   - `Cmd + Q` (macOS)
   - `Alt + F4` or close window (Windows/Linux)

2. **Reopen Cursor**

## ✅ Step 7: Verify Connection

1. **Check MCP Status:**
   - Open Settings → MCP
   - You should see "Wikipedia" in the list
   - Status should show as "Connected" or have a green indicator

2. **Test in Cursor Chat:**
   - Open Cursor's chat panel:
     - Press `Cmd + L` (macOS) or `Ctrl + L` (Windows/Linux)
     - Or click the chat icon in the sidebar
   
   - Try this command:
     ```
     Use the Wikipedia MCP tool to get a summary about Archimedes
     ```
   
   - Or:
     ```
     Search Wikipedia for information about Isaac Newton
     ```

3. **Expected behavior:**
   - Cursor should recognize the MCP tools
   - You should see Wikipedia content in the response
   - No error messages

## ✅ Step 8: Use the MCP Server

Now you can use natural language queries in Cursor:

- "Get the Wikipedia summary for Blaise Pascal"
- "Search Wikipedia for Charles's Law"
- "What does Wikipedia say about Evangelista Torricelli?"
- "Fetch detailed information about Robert Boyle from Wikipedia"

## 🔧 Troubleshooting

### Problem: "Server not found" or "Command not found"

**Solution:**
1. Verify the path is correct:
   ```bash
   ls -la /Users/cchia/projects/science_map/mcp-wikipedia-server/index.js
   ```
2. Check Node.js is in PATH:
   ```bash
   which node
   ```
3. Use absolute path in Cursor settings

### Problem: "Cannot find module '@modelcontextprotocol/sdk'"

**Solution:**
```bash
cd /Users/cchia/projects/science_map/mcp-wikipedia-server
npm install
```

### Problem: Server shows as disconnected

**Solution:**
1. Check the server path in Cursor settings
2. Test the server manually:
   ```bash
   node /Users/cchia/projects/science_map/mcp-wikipedia-server/index.js
   ```
3. Check Cursor's MCP logs (usually in Settings → MCP → Logs)

### Problem: "Article not found" errors

**Solution:**
- Wikipedia titles are case-sensitive
- Use exact article titles (e.g., "Isaac Newton" not "isaac newton")
- Try the search tool first to find the correct title

### Problem: No response from Wikipedia API

**Solution:**
1. Test API connectivity:
   ```bash
   curl "https://en.wikipedia.org/api/rest_v1/page/summary/Test"
   ```
2. Check your internet connection
3. Verify firewall settings

## 📝 Next Steps

Once working, you can:

1. **Customize the server:**
   - Edit `index.js` to add more tools
   - Change Wikipedia language
   - Add caching for better performance

2. **Integrate with your project:**
   - Use MCP to fetch data for your science_map JSON files
   - Automate content updates
   - Pull images and metadata

3. **Extend functionality:**
   - Add support for other wikis
   - Create batch operations
   - Add custom search filters

## 🎉 Success!

If you can query Wikipedia through Cursor, you're all set! The MCP server is working correctly.

For more information, see:
- `README.md` - Full documentation
- `QUICK_START.md` - Quick reference
- `cursor-config-example.json` - Configuration template

