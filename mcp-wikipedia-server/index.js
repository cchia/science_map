#!/usr/bin/env node

/**
 * MCP Server for Wikipedia REST API
 * 
 * This server provides tools to interact with Wikipedia's REST API,
 * allowing you to search articles, get summaries, and fetch full content.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// Node 18+ has native fetch available globally
// node-fetch is included as a dependency for compatibility, but native fetch is used

const WIKIPEDIA_API_BASE = process.env.WIKI_API_URL || "https://en.wikipedia.org/api/rest_v1";
const WIKI_LANG = process.env.WIKI_LANG || "en";

class WikipediaServer {
  constructor() {
    this.server = new Server(
      {
        name: "wikipedia-mcp-server",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupResourceHandlers();
    this.setupErrorHandling();
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error("[MCP Error]", error);
    };

    process.on("SIGINT", async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: "wikipedia_search",
            description:
              "Search Wikipedia articles by query. Returns a list of matching article titles and snippets.",
            inputSchema: {
              type: "object",
              properties: {
                query: {
                  type: "string",
                  description: "Search query (e.g., 'Archimedes', 'quantum mechanics')",
                },
                limit: {
                  type: "number",
                  description: "Maximum number of results (default: 10)",
                  default: 10,
                },
              },
              required: ["query"],
            },
          },
          {
            name: "wikipedia_get_summary",
            description:
              "Get a summary of a Wikipedia article by title. Returns a concise overview of the topic.",
            inputSchema: {
              type: "object",
              properties: {
                title: {
                  type: "string",
                  description: "Exact Wikipedia article title (e.g., 'Archimedes', 'Isaac Newton')",
                },
              },
              required: ["title"],
            },
          },
          {
            name: "wikipedia_get_content",
            description:
              "Get the full HTML content of a Wikipedia article by title.",
            inputSchema: {
              type: "object",
              properties: {
                title: {
                  type: "string",
                  description: "Exact Wikipedia article title",
                },
              },
              required: ["title"],
            },
          },
          {
            name: "wikipedia_get_page_info",
            description:
              "Get detailed information about a Wikipedia page including summary, images, and metadata.",
            inputSchema: {
              type: "object",
              properties: {
                title: {
                  type: "string",
                  description: "Exact Wikipedia article title",
                },
              },
              required: ["title"],
            },
          },
        ],
      };
    });

    // Handle tool execution
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "wikipedia_search":
            return await this.searchWikipedia(args.query, args.limit || 10);

          case "wikipedia_get_summary":
            return await this.getSummary(args.title);

          case "wikipedia_get_content":
            return await this.getContent(args.title);

          case "wikipedia_get_page_info":
            return await this.getPageInfo(args.title);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  setupResourceHandlers() {
    // List available resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => {
      return {
        resources: [
          {
            uri: "wikipedia://search",
            name: "Wikipedia Search",
            description: "Search Wikipedia articles",
            mimeType: "application/json",
          },
        ],
      };
    });

    // Handle resource reading
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;
      
      if (uri.startsWith("wikipedia://search?q=")) {
        const query = decodeURIComponent(uri.split("?q=")[1]);
        const result = await this.searchWikipedia(query, 10);
        return {
          contents: [
            {
              uri,
              mimeType: "application/json",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      throw new Error(`Unknown resource: ${uri}`);
    });
  }

  async searchWikipedia(query, limit = 10) {
    try {
      const url = `${WIKIPEDIA_API_BASE}/page/summary/${encodeURIComponent(query)}`;
      const response = await fetch(url);

      if (response.status === 404) {
        // If exact match not found, try search
        const searchUrl = `https://${WIKI_LANG}.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(query)}&format=json&srlimit=${limit}`;
        const searchResponse = await fetch(searchUrl);
        const searchData = await searchResponse.json();

        if (searchData.query?.search?.length > 0) {
          const results = searchData.query.search.map((item) => ({
            title: item.title,
            snippet: item.snippet,
            size: item.size,
            wordcount: item.wordcount,
          }));

          return {
            content: [
              {
                type: "text",
                text: `Found ${results.length} search results:\n\n${results
                  .map(
                    (r, i) =>
                      `${i + 1}. **${r.title}**\n   ${r.snippet}\n`
                  )
                  .join("\n")}`,
              },
            ],
          };
        }

        return {
          content: [
            {
              type: "text",
              text: `No results found for "${query}"`,
            },
          ],
        };
      }

      if (!response.ok) {
        throw new Error(`Wikipedia API error: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        content: [
          {
            type: "text",
            text: `**${data.title}**\n\n${data.extract}\n\nSource: ${data.content_urls?.desktop?.page || "N/A"}`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Search failed: ${error.message}`);
    }
  }

  async getSummary(title) {
    try {
      const url = `${WIKIPEDIA_API_BASE}/page/summary/${encodeURIComponent(title)}`;
      const response = await fetch(url);

      if (!response.ok) {
        if (response.status === 404) {
          throw new Error(`Article not found: "${title}"`);
        }
        throw new Error(`Wikipedia API error: ${response.statusText}`);
      }

      const data = await response.json();
      return {
        content: [
          {
            type: "text",
            text: `# ${data.title}\n\n${data.extract}\n\n**Type:** ${data.type}\n**Original Source:** ${data.content_urls?.desktop?.page || "N/A"}`,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to get summary: ${error.message}`);
    }
  }

  async getContent(title) {
    try {
      const url = `${WIKIPEDIA_API_BASE}/page/html/${encodeURIComponent(title)}`;
      const response = await fetch(url);

      if (!response.ok) {
        if (response.status === 404) {
          throw new Error(`Article not found: "${title}"`);
        }
        throw new Error(`Wikipedia API error: ${response.statusText}`);
      }

      const html = await response.text();
      return {
        content: [
          {
            type: "text",
            text: html,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to get content: ${error.message}`);
    }
  }

  async getPageInfo(title) {
    try {
      const url = `${WIKIPEDIA_API_BASE}/page/summary/${encodeURIComponent(title)}`;
      const response = await fetch(url);

      if (!response.ok) {
        if (response.status === 404) {
          throw new Error(`Article not found: "${title}"`);
        }
        throw new Error(`Wikipedia API error: ${response.statusText}`);
      }

      const data = await response.json();
      const info = {
        title: data.title,
        extract: data.extract,
        type: data.type,
        thumbnail: data.thumbnail?.source,
        description: data.description,
        coordinates: data.coordinates,
        content_urls: data.content_urls,
        pageid: data.pageid,
      };

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(info, null, 2),
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to get page info: ${error.message}`);
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Wikipedia MCP server running on stdio");
  }
}

const server = new WikipediaServer();
server.run().catch(console.error);

