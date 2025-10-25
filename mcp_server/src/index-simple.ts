#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { FirebaseService } from './firebase-service-simple.js';

const server = new Server(
  {
    name: 'gavra-firestore-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

const firebaseService = new FirebaseService();

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'firestore_get_document',
        description: 'Get a document from Firestore by collection and document ID',
        inputSchema: {
          type: 'object',
          properties: {
            collection: { type: 'string', description: 'Collection name' },
            documentId: { type: 'string', description: 'Document ID' },
          },
          required: ['collection', 'documentId'],
        },
      },
      {
        name: 'firestore_set_document',
        description: 'Create or update a document in Firestore',
        inputSchema: {
          type: 'object',
          properties: {
            collection: { type: 'string', description: 'Collection name' },
            documentId: { type: 'string', description: 'Document ID' },
            data: { type: 'object', description: 'Document data' },
          },
          required: ['collection', 'documentId', 'data'],
        },
      },
      {
        name: 'get_dnevni_putnici',
        description: 'Get daily passengers for a specific date',
        inputSchema: {
          type: 'object',
          properties: {
            datum: { type: 'string', description: 'Date in YYYY-MM-DD format' },
          },
          required: ['datum'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'firestore_get_document': {
        const doc = await firebaseService.getDocument(args?.collection as string, args?.documentId as string);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(doc, null, 2),
            },
          ],
        };
      }

      case 'firestore_set_document': {
        await firebaseService.setDocument(args?.collection as string, args?.documentId as string, args?.data as any);
        return {
          content: [
            {
              type: 'text',
              text: 'Document saved successfully',
            },
          ],
        };
      }

      case 'get_dnevni_putnici': {
        const dnevniPutnici = await firebaseService.getDnevniPutnici(args?.datum as string);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(dnevniPutnici, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Gavra Firestore MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});