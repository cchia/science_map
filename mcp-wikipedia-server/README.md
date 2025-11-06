# Wikipedia MCP Server - Step-by-Step Setup Guide

This guide will walk you through setting up a custom MCP server that connects to Wikipedia's REST API and integrates it with Cursor IDE.

## Prerequisites

Before starting, ensure you have:
- **Node.js** installed (version 18 or higher)
  - Check: `node --version`
  - Download: https://nodejs.org/
- **npm** (comes with Node.js)
  - Check: `npm --version`
- **Cursor IDE** installed

## Step 1: Install Dependencies

1. **Navigate to the MCP server directory:**
   ```bash
   cd /Users/cchia/projects/science_map/mcp-wikipedia-server
   ```

2. **Install the required packages:**
   ```bash
   npm install
   ```
   
   This will install:
   - `@modelcontextprotocol/sdk` - The MCP SDK for building servers
   - `node-fetch` - For making HTTP requests to Wikipedia's API

3. **Verify installation:**
   ```bash
   ls node_modules
   ```
   You should see the installed packages.

## Step 2: Test the Server Locally

Before connecting to Cursor, let's test that the server works:

1. **Test the server directly:**
   ```bash
   node index.js
   ```
   
   The server should start and wait for input on stdio. Press `Ctrl+C` to stop.

2. **Test Wikipedia API connectivity:**
   ```bash
   curl "https://en.wikipedia.org/api/rest_v1/page/summary/Archimedes"
   ```
   
   You should see JSON data about Archimedes.

## Step 3: Make the Script Executable (macOS/Linux)

```bash
chmod +x index.js
```

This allows the script to be run directly.

## Step 4: Configure Cursor to Use the MCP Server

You have two options to configure Cursor:

### Option A: Using Cursor's Settings UI (Recommended)

1. **Open Cursor Settings:**
   - Press `Cmd + ,` (macOS) or `Ctrl + ,` (Windows/Linux)
   - Or go to: `Cursor` → `Settings`

2. **Navigate to MCP Settings:**
   - In the search bar, type "MCP"
   - Click on "Features" → "MCP" or "Model Context Protocol"

3. **Add New MCP Server:**
   - Click the `+ Add New MCP Server` button
   - Fill in the following:
     - **Name:** `Wikipedia`
     - **Transport Type:** `stdio`
     - **Command:** `node`
     - **Arguments:** 
       ```
       /Users/cchia/projects/science_map/mcp-wikipedia-server/index.js
       ```
     - **Environment Variables (optional):**
       - `WIKI_API_URL`: `https://en.wikipedia.org/api/rest_v1` (default)
       - `WIKI_LANG`: `en` (default)

4. **Save the configuration**

### Option B: Edit Configuration File Directly

1. **Find the MCP configuration file:**
   - **macOS:** `~/Library/Application Support/Cursor/User/globalStorage/mcp.json`
   - **Linux:** `~/.config/cursor/mcp.json`
   - **Windows:** `%APPDATA%\Cursor\User\globalStorage\mcp.json`

2. **Create or edit the file:**
   ```bash
   # macOS
   nano ~/Library/Application\ Support/Cursor/User/globalStorage/mcp.json
   ```

3. **Add the server configuration:**
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

4. **Save the file and restart Cursor**

## Step 5: Verify the Connection

1. **Restart Cursor** (if you edited the config file directly)

2. **Check MCP Status:**
   - Go back to Cursor Settings → MCP
   - You should see "Wikipedia" listed as a connected server
   - Status should show as "Connected" or "Active"

3. **Test in Cursor Chat:**
   - Open Cursor's chat panel (`Cmd/Ctrl + L`)
   - Try asking:
     ```
     Use the Wikipedia MCP to search for information about Archimedes
     ```
   - Or:
     ```
     Get the Wikipedia summary for Isaac Newton
     ```

## Step 6: Available Tools

Once connected, you can use these tools through Cursor:

### 1. `wikipedia_search`
Search for Wikipedia articles:
- **Query:** Search term (e.g., "Archimedes", "quantum mechanics")
- **Limit:** Maximum number of results (default: 10)

### 2. `wikipedia_get_summary`
Get a concise summary of an article:
- **Title:** Exact article title (e.g., "Archimedes", "Isaac Newton")

### 3. `wikipedia_get_content`
Get full HTML content of an article:
- **Title:** Exact article title

### 4. `wikipedia_get_page_info`
Get detailed information including images and metadata:
- **Title:** Exact article title

## Example Usage in Cursor

Once set up, you can ask Cursor:

- "Search Wikipedia for information about Blaise Pascal"
- "Get the Wikipedia summary for Robert Boyle"
- "Fetch detailed information about the Charles's Law Wikipedia page"
- "What does Wikipedia say about Evangelista Torricelli?"

## Troubleshooting

### Server Not Starting

**Error:** `Cannot find module '@modelcontextprotocol/sdk'`
- **Solution:** Run `npm install` in the server directory

**Error:** `Permission denied`
- **Solution:** Make the script executable: `chmod +x index.js`

### Connection Issues

**Server shows as disconnected:**
1. Check the path in Cursor's MCP settings is correct
2. Verify Node.js is in your PATH: `which node`
3. Try running the server manually: `node /path/to/index.js`

**No response from Wikipedia:**
1. Test API connectivity: `curl "https://en.wikipedia.org/api/rest_v1/page/summary/Test"`
2. Check your internet connection
3. Verify the API URL is correct

### Getting 404 Errors

If you get "Article not found" errors:
- Make sure you're using the exact Wikipedia article title
- Wikipedia titles are case-sensitive
- Some articles may not exist in the language you specified
- Try using the search tool first to find the correct title

## Advanced Configuration

### Using Different Wikipedia Languages

To use a different language version:

1. **Edit the environment variable:**
   ```json
   "env": {
     "WIKI_API_URL": "https://es.wikipedia.org/api/rest_v1",
     "WIKI_LANG": "es"
   }
   ```

2. **Available languages:**
   - English: `en.wikipedia.org`
   - Spanish: `es.wikipedia.org`
   - French: `fr.wikipedia.org`
   - German: `de.wikipedia.org`
   - And many more...

### Customizing the Server

You can modify `index.js` to:
- Add more tools
- Change the API endpoints
- Add caching
- Add authentication for private wikis

## Next Steps

Now that you have Wikipedia MCP connected, you can:

1. **Enhance your science_map project:**
   - Automatically fetch article summaries for historical figures
   - Pull images and metadata
   - Update your JSON files with Wikipedia data

2. **Create custom tools:**
   - Add tools for specific Wikipedia operations
   - Integrate with your existing Python scripts

3. **Extend functionality:**
   - Add support for other wiki platforms
   - Create tools for batch operations

## Resources

- [Wikipedia REST API Documentation](https://www.mediawiki.org/wiki/Wikimedia_REST_API)
- [MCP Protocol Specification](https://modelcontextprotocol.io)
- [Cursor MCP Documentation](https://docs.cursor.com/context/model-context-protocol)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the server logs in Cursor's MCP settings
3. Test the Wikipedia API directly with curl
4. Verify Node.js and npm versions are compatible


