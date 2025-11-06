# Finding MCP Settings in Cursor - Alternative Methods

If you can't find "Model Context Protocol" or "Features: MCP" in Cursor's settings, use one of these methods:

## Method 1: Direct File Configuration (Recommended if UI not found)

This method works regardless of Cursor's UI version.

### Step 1: Locate the Config File

The MCP configuration file should be at:
```
~/Library/Application Support/Cursor/User/globalStorage/mcp.json
```

### Step 2: Create the File

1. **Open Terminal** and run:
   ```bash
   # Create the directory if it doesn't exist
   mkdir -p ~/Library/Application\ Support/Cursor/User/globalStorage
   
   # Create the config file
   nano ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json
   ```

2. **Paste this configuration:**
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

3. **Save and exit:**
   - Press `Ctrl + X`
   - Press `Y` to confirm
   - Press `Enter` to save

### Step 3: Restart Cursor

Completely quit and restart Cursor for the changes to take effect.

## Method 2: Using Finder (macOS)

1. **Open Finder**
2. **Press `Cmd + Shift + G`** (Go to Folder)
3. **Paste this path:**
   ```
   ~/Library/Application Support/Cursor/User/globalStorage
   ```
4. **Press Enter**
5. **Create a new file** called `mcp.json`
6. **Copy the JSON configuration** from above
7. **Save the file**

## Method 3: Check Cursor Version

If MCP settings aren't visible, you might need to:

1. **Update Cursor** to the latest version
   - Go to `Cursor` → `Check for Updates` (macOS)
   - Or download from: https://cursor.sh

2. **Check if MCP is enabled:**
   - Some Cursor versions require enabling MCP in settings first
   - Look for "Experimental Features" or "Beta Features"

## Method 4: Verify the Config File Location

Run this command to check if the file exists or where it should be:

```bash
# Check if the directory exists
ls -la ~/Library/Application\ Support/Cursor/User/globalStorage/

# Check if mcp.json exists
ls -la ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json

# If it doesn't exist, create it
cat > ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json << 'EOF'
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
EOF
```

## Verification

After creating the file, verify it:

```bash
# Check the file was created
cat ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json
```

You should see the JSON configuration.

## Next Steps

1. **Restart Cursor completely**
2. **Test the connection** by asking Cursor:
   ```
   Get a Wikipedia summary about Archimedes
   ```

If you still have issues, check the troubleshooting section in SETUP_STEPS.md


