#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { FirebaseService } from './firebase-service.js';

const server = new Server(
  {
    name: "gavra-firestore-mcp-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Initialize Firebase
const firebaseService = new FirebaseService();

// Define available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      // Putnici (Passengers) tools
      {
        name: "get_putnici",
        description: "Get all active passengers",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
      {
        name: "add_putnik",
        description: "Add a new passenger",
        inputSchema: {
          type: "object",
          properties: {
            ime: { type: "string", description: "Passenger name" },
            prezime: { type: "string", description: "Passenger surname" },
            telefon: { type: "string", description: "Phone number" },
            adresa: { type: "string", description: "Address" },
            kusur: { type: "number", description: "Change amount", default: 0 },
            obrisan: { type: "boolean", description: "Deleted flag", default: false },
            created_at: { type: "string", description: "Creation timestamp" },
          },
          required: ["ime", "prezime", "telefon", "adresa"],
        },
      },
      {
        name: "update_putnik",
        description: "Update an existing passenger",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Passenger ID" },
            updates: {
              type: "object",
              description: "Fields to update",
              properties: {
                ime: { type: "string" },
                prezime: { type: "string" },
                telefon: { type: "string" },
                adresa: { type: "string" },
                kusur: { type: "number" },
                obrisan: { type: "boolean" },
              },
            },
          },
          required: ["id", "updates"],
        },
      },
      {
        name: "delete_putnik",
        description: "Soft delete a passenger",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Passenger ID" },
          },
          required: ["id"],
        },
      },
      
      // Dnevni Putnici (Daily Passengers) tools
      {
        name: "get_dnevni_putnici",
        description: "Get daily passengers for a specific date",
        inputSchema: {
          type: "object",
          properties: {
            datum: { type: "string", description: "Date in YYYY-MM-DD format" },
          },
          required: ["datum"],
        },
      },
      {
        name: "add_dnevni_putnik",
        description: "Add a daily passenger entry",
        inputSchema: {
          type: "object",
          properties: {
            putnik_id: { type: "string", description: "Passenger ID" },
            datum: { type: "string", description: "Date in YYYY-MM-DD format" },
            tip_karte: { type: "string", description: "Ticket type" },
            cena_karte: { type: "number", description: "Ticket price" },
            kusur: { type: "number", description: "Change amount", default: 0 },
            placeno: { type: "boolean", description: "Payment status", default: false },
            vozac_id: { type: "string", description: "Driver ID" },
            created_at: { type: "string", description: "Creation timestamp" },
          },
          required: ["putnik_id", "datum", "tip_karte", "cena_karte", "vozac_id"],
        },
      },
      {
        name: "update_dnevni_putnik",
        description: "Update a daily passenger entry",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Daily passenger ID" },
            updates: {
              type: "object",
              description: "Fields to update",
              properties: {
                tip_karte: { type: "string" },
                cena_karte: { type: "number" },
                kusur: { type: "number" },
                placeno: { type: "boolean" },
              },
            },
          },
          required: ["id", "updates"],
        },
      },
      {
        name: "delete_dnevni_putnik",
        description: "Delete a daily passenger entry",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Daily passenger ID" },
          },
          required: ["id"],
        },
      },

      // GPS Lokacije (GPS Locations) tools
      {
        name: "get_gps_lokacije",
        description: "Get GPS locations for a specific date range",
        inputSchema: {
          type: "object",
          properties: {
            start_date: { type: "string", description: "Start date in YYYY-MM-DD format" },
            end_date: { type: "string", description: "End date in YYYY-MM-DD format" },
            vozac_id: { type: "string", description: "Driver ID (optional)" },
          },
          required: ["start_date", "end_date"],
        },
      },
      {
        name: "add_gps_lokacija",
        description: "Add a GPS location entry",
        inputSchema: {
          type: "object",
          properties: {
            latitude: { type: "number", description: "Latitude coordinate" },
            longitude: { type: "number", description: "Longitude coordinate" },
            accuracy: { type: "number", description: "GPS accuracy in meters" },
            speed: { type: "number", description: "Speed in m/s", default: 0 },
            heading: { type: "number", description: "Heading in degrees", default: 0 },
            altitude: { type: "number", description: "Altitude in meters", default: 0 },
            vozac_id: { type: "string", description: "Driver ID" },
            timestamp: { type: "string", description: "Timestamp" },
          },
          required: ["latitude", "longitude", "accuracy", "vozac_id", "timestamp"],
        },
      },

      // Analytics and Statistics tools
      {
        name: "get_daily_statistics",
        description: "Get daily statistics for passengers and revenue",
        inputSchema: {
          type: "object",
          properties: {
            datum: { type: "string", description: "Date in YYYY-MM-DD format" },
            vozac_id: { type: "string", description: "Driver ID (optional)" },
          },
          required: ["datum"],
        },
      },
      {
        name: "get_monthly_statistics",
        description: "Get monthly statistics",
        inputSchema: {
          type: "object",
          properties: {
            year: { type: "number", description: "Year" },
            month: { type: "number", description: "Month (1-12)" },
            vozac_id: { type: "string", description: "Driver ID (optional)" },
          },
          required: ["year", "month"],
        },
      },

      // Real-time streaming tools
      {
        name: "stream_putnici",
        description: "Get real-time stream of passengers (returns snapshot)",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
      {
        name: "stream_dnevni_putnici",
        description: "Get real-time stream of daily passengers for a date",
        inputSchema: {
          type: "object",
          properties: {
            datum: { type: "string", description: "Date in YYYY-MM-DD format" },
          },
          required: ["datum"],
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
      // Putnici operations
      case "get_putnici": {
        const putnici = await firebaseService.getPutnici();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(putnici, null, 2),
            },
          ],
        };
      }

      case "add_putnik": {
        const newPutnikId = await firebaseService.addPutnik(args);
        return {
          content: [
            {
              type: "text",
              text: `Putnik added with ID: ${newPutnikId}`,
            },
          ],
        };
      }

      case "update_putnik": {
        const updateResult = await firebaseService.updatePutnik(args.id as string, args.updates);
        return {
          content: [
            {
              type: "text",
              text: updateResult ? "Passenger updated successfully" : "Failed to update passenger",
            },
          ],
        };
      }

      case "delete_putnik": {
        const deleteResult = await firebaseService.deletePutnik(args.id as string);
        return {
          content: [
            {
              type: "text",
              text: deleteResult ? "Passenger deleted successfully" : "Failed to delete passenger",
            },
          ],
        };
      }

      // Dnevni Putnici operations
      case "get_dnevni_putnici": {
        const dnevniPutnici = await firebaseService.getDnevniPutnici(args.datum as string);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(dnevniPutnici, null, 2),
            },
          ],
        };
      }

      case "add_dnevni_putnik": {
        const newDnevniPutnikId = await firebaseService.addDnevniPutnik(args);
        return {
          content: [
            {
              type: "text",
              text: `Successfully added daily passenger with ID: ${newDnevniPutnikId}`,
            },
          ],
        };
      }

      case "update_dnevni_putnik": {
        const updateDnevniResult = await firebaseService.updateDnevniPutnik(args.id as string, args.updates);
        return {
          content: [
            {
              type: "text",
              text: updateDnevniResult ? "Daily passenger updated successfully" : "Failed to update daily passenger",
            },
          ],
        };
      }

      case "delete_dnevni_putnik": {
        const deleteDnevniResult = await firebaseService.deleteDnevniPutnik(args.id as string);
        return {
          content: [
            {
              type: "text",
              text: deleteDnevniResult ? "Daily passenger deleted successfully" : "Failed to delete daily passenger",
            },
          ],
        };
      }

      // GPS Lokacije operations
      case "get_gps_lokacije": {
        const gpsLokacije = await firebaseService.getGpsLokacije(args.start_date as string, args.end_date as string, args.vozac_id as string);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(gpsLokacije, null, 2),
            },
          ],
        };
      }

      case "add_gps_lokacija": {
        const newGpsId = await firebaseService.addGpsLokacija(args);
        return {
          content: [
            {
              type: "text",
              text: `Successfully added GPS location with ID: ${newGpsId}`,
            },
          ],
        };
      }

      // Statistics operations
      case "get_daily_statistics": {
        const dailyStats = await firebaseService.getDailyStatistics(args.datum as string, args.vozac_id as string);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(dailyStats, null, 2),
            },
          ],
        };
      }

      case "get_monthly_statistics": {
        const monthlyStats = await firebaseService.getMonthlyStatistics(args.year as number, args.month as number, args.vozac_id as string);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(monthlyStats, null, 2),
            },
          ],
        };
      }

      // Real-time streaming (returns snapshots)
      case "stream_putnici": {
        const putniciSnapshot = await firebaseService.getPutnici();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(putniciSnapshot, null, 2),
            },
          ],
        };
      }

      case "stream_dnevni_putnici": {
        const dnevniSnapshot = await firebaseService.getDnevniPutnici(args.datum as string);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(dnevniSnapshot, null, 2),
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
          type: "text",
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Gavra Firestore MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error in main():", error);
  process.exit(1);
});