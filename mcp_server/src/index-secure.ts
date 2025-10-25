#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { SecureFirebaseService } from './secure-firebase-service.js';

const server = new Server(
  {
    name: 'gavra-secure-firestore-mcp-server',
    version: '1.0.0-secure',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// 🔒 SIGURNI NAČIN - samo read-only pristup
const firebaseService = new SecureFirebaseService(true); // READ-ONLY mode

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'firestore_get_document',
        description: '🔍 SAFE: Get a document from Firestore (read-only)',
        inputSchema: {
          type: 'object',
          properties: {
            collection: { 
              type: 'string', 
              description: 'Collection name (limited to: putnici, dnevni_putnici, vozaci, rute)',
              enum: ['putnici', 'dnevni_putnici', 'vozaci', 'rute', 'gps_lokacije']
            },
            documentId: { type: 'string', description: 'Document ID' },
          },
          required: ['collection', 'documentId'],
        },
      },
      {
        name: 'get_dnevni_putnici',
        description: '📅 SAFE: Get daily passengers for a specific date (read-only)',
        inputSchema: {
          type: 'object',
          properties: {
            datum: { type: 'string', description: 'Date in YYYY-MM-DD format' },
          },
          required: ['datum'],
        },
      },
      {
        name: 'get_basic_statistics',
        description: '📊 SAFE: Get basic statistics (read-only)',
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
              text: `🔒 SECURE READ: ${JSON.stringify(doc, null, 2)}`,
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
              text: `📅 Daily passengers (${dnevniPutnici.length} found):\n${JSON.stringify(dnevniPutnici, null, 2)}`,
            },
          ],
        };
      }

      case 'get_basic_statistics': {
        const putnici = await firebaseService.getDnevniPutnici(args?.datum as string);
        const stats = {
          datum: args?.datum,
          ukupno_putnika: putnici.length,
          timestamp: new Date().toISOString(),
          security_mode: 'READ_ONLY'
        };
        return {
          content: [
            {
              type: 'text',
              text: `📊 SAFE Statistics:\n${JSON.stringify(stats, null, 2)}`,
            },
          ],
        };
      }

      default:
        throw new Error(`🚫 Unknown or disabled tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `🚨 SECURITY ERROR: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('🔒 Gavra SECURE Firestore MCP server running (READ-ONLY mode)');
}

main().catch((error) => {
  console.error('🚨 Server security error:', error);
  process.exit(1);
});