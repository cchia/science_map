# Connecting Cursor to Wiki Database with MCP

This guide explains how to connect Cursor IDE to a wiki database (e.g., Wikipedia) using the Model Context Protocol (MCP).

## Prerequisites

- Node.js installed (for MCP servers)
- Cursor IDE with MCP support enabled

## Step 1: Install an MCP Server for Wikipedia/Wiki

There are several options for wiki MCP servers. Here are the most common approaches:

### Option A: Use an Existing Wikipedia MCP Server

1. **Check Available MCP Servers:**
   Visit the [MCP Servers Directory](https://github.com/modelcontextprotocol/servers) to find available servers.
   
2. **Install via npm (example):**
   ```bash
   # Check if a Wikipedia MCP server exists
   npm search mcp wikipedia
   
   # Install if available (example format)
   npm install -g @modelcontextprotocol/server-wikipedia
   ```

3. **Alternative: Build Your Own**
   Since Wikipedia has a public REST API, you can create a simple MCP server or use one from the community.

### Option B: Use a Generic Wiki MCP Server

For custom wikis or MediaWiki installations:
```bash
npm install -g @modelcontextprotocol/server-mediawiki
```

## Step 2: Configure Cursor MCP Settings

The MCP configuration in Cursor is typically stored in:
- **macOS:** `~/Library/Application Support/Cursor/User/globalStorage/mcp.json` or `~/.cursor/mcp.json`
- **Linux:** `~/.config/cursor/mcp.json` or `~/.cursor/mcp.json`
- **Windows:** `%APPDATA%\Cursor\User\globalStorage\mcp.json` or `%APPDATA%\Cursor\mcp.json`

**Note:** The exact location may vary. Check Cursor's settings UI or documentation for the current path.

### Configuration Format

Open or create the MCP configuration file and add:

```json
{
  "mcpServers": {
    "wikipedia": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-wikipedia"
      ],
      "env": {}
    }
  }
}
```

**Important:** The exact package name may vary. Check the [MCP Servers repository](https://github.com/modelcontextprotocol/servers) for the correct package name.

### Alternative: Using a Local Installation

If you installed the server globally or locally:

```json
{
  "mcpServers": {
    "wikipedia": {
      "command": "node",
      "args": [
        "/path/to/mcp-server-wikipedia/index.js"
      ],
      "env": {
        "WIKI_API_URL": "https://en.wikipedia.org/api/rest_v1",
        "WIKI_LANG": "en"
      }
    }
  }
}
```

### For Custom Wiki/MediaWiki

```json
{
  "mcpServers": {
    "my-wiki": {
      "command": "node",
      "args": [
        "/path/to/mcp-server-mediawiki/index.js"
      ],
      "env": {
        "WIKI_API_URL": "https://your-wiki.com/api.php",
        "WIKI_USERNAME": "your-username",
        "WIKI_PASSWORD": "your-password",
        "WIKI_DOMAIN": "your-wiki.com"
      }
    }
  }
}
```

## Step 3: Configure in Cursor UI

1. **Open Cursor Settings:**
   - Go to `Settings` → `Features` → `MCP`
   - Or use `Cmd/Ctrl + ,` and search for "MCP"

2. **Add MCP Server:**
   - Click `+ Add New MCP Server`
   - Enter a name (e.g., "Wikipedia")
   - Select transport type: `stdio` (most common)
   - Enter the command and arguments

3. **Alternative: Edit Config File Directly**
   - Open the MCP config file location mentioned above
   - Add your server configuration
   - Restart Cursor

## Step 4: Verify Connection

1. **Check MCP Status:**
   - In Cursor, go to the MCP settings
   - Verify the server shows as "Connected" or "Active"

2. **Test with a Query:**
   - In Cursor's chat, try: "Fetch information about Archimedes from Wikipedia"
   - The MCP server should process the request

## Step 5: Using MCP Tools in Cursor

Once connected, you can use natural language queries like:

- "Get the Wikipedia article about Isaac Newton"
- "Search Wikipedia for information about quantum mechanics"
- "Fetch the summary of Einstein's theory of relativity from Wikipedia"

## Troubleshooting

### Server Not Found
- Ensure Node.js is installed: `node --version`
- Verify the MCP server package is installed globally: `npm list -g | grep wikipedia`
- Check the command path in your config

### Connection Errors
- Verify the API endpoint is correct
- Check network connectivity
- Ensure authentication credentials are correct (if required)

### Permission Issues
- Make sure the MCP server executable has proper permissions
- On macOS/Linux, you may need `chmod +x` on scripts

## Example MCP Servers

Popular MCP servers for wikis:
- Check the [official MCP Servers repository](https://github.com/modelcontextprotocol/servers) for available implementations
- Community servers for Wikipedia, MediaWiki, Confluence, etc.
- You can also build custom servers using the [MCP SDK](https://github.com/modelcontextprotocol/typescript-sdk)

## Quick Setup for Wikipedia (Using REST API)

Since Wikipedia has a public REST API, you can quickly test connectivity:

1. **Test Wikipedia API:**
   ```bash
   curl "https://en.wikipedia.org/api/rest_v1/page/summary/Archimedes"
   ```

2. **Create a Simple MCP Server:**
   You can create a Node.js MCP server that uses Wikipedia's REST API. See the MCP documentation for creating custom servers.

## Resources

- [Cursor MCP Documentation](https://docs.cursor.com/context/model-context-protocol)
- [Model Context Protocol Specification](https://modelcontextprotocol.io)
- [MCP Server Examples](https://github.com/modelcontextprotocol/servers)

## Notes for This Project

Since you're already using Wikipedia images (see `add_wiki_images.py`), connecting MCP to Wikipedia will allow you to:
- Fetch article content directly
- Search for scientific figures and events
- Get structured data for your JSON files
- Automate content updates

