import admin from 'firebase-admin';
import { z } from 'zod';

// Zod schemas for type validation
const PutnikSchema = z.object({
  ime: z.string(),
  prezime: z.string(),
  telefon: z.string(),
  adresa: z.string(),
  kusur: z.number().default(0),
  obrisan: z.boolean().default(false),
  created_at: z.string().optional(),
});

const DnevniPutnikSchema = z.object({
  putnik_id: z.string(),
  datum: z.string(),
  tip_karte: z.string(),
  cena_karte: z.number(),
  kusur: z.number().default(0),
  placeno: z.boolean().default(false),
  vozac_id: z.string(),
  created_at: z.string().optional(),
});

const GpsLokacijaSchema = z.object({
  latitude: z.number(),
  longitude: z.number(),
  accuracy: z.number(),
  speed: z.number().default(0),
  heading: z.number().default(0),
  altitude: z.number().default(0),
  vozac_id: z.string(),
  timestamp: z.string(),
});

export type Putnik = z.infer<typeof PutnikSchema>;
export type DnevniPutnik = z.infer<typeof DnevniPutnikSchema>;
export type GpsLokacija = z.infer<typeof GpsLokacijaSchema>;

export class FirebaseService {
  private db: admin.firestore.Firestore;

  constructor() {
    // Initialize Firebase Admin (you'll need to set up service account)
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        // You can also use a service account key file:
        // credential: admin.credential.cert(require('./path/to/serviceAccountKey.json')),
        databaseURL: 'https://gavra-notif-20250920162521-default-rtdb.firebaseio.com',
      });
    }
    this.db = admin.firestore();
  }

  // Collection references
  private get putnici() {
    return this.db.collection('putnici');
  }

  private get dnevniPutnici() {
    return this.db.collection('dnevni_putnici');
  }

  private get gpsLokacije() {
    return this.db.collection('gps_lokacije');
  }

  // PUTNICI OPERATIONS

  async getPutnici(): Promise<any[]> {
    try {
      const snapshot = await this.putnici.where('obrisan', '==', false).get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      console.error('Error getting putnici:', error);
      return [];
    }
  }

  async addPutnik(data: Putnik): Promise<string> {
    try {
      const validatedData = PutnikSchema.parse(data);
      if (!validatedData.created_at) {
        validatedData.created_at = new Date().toISOString();
      }
      
      const docRef = await this.putnici.add(validatedData);
      return docRef.id;
    } catch (error) {
      console.error('Error adding putnik:', error);
      throw error;
    }
  }

  async updatePutnik(id: string, updates: Partial<Putnik>): Promise<boolean> {
    try {
      await this.putnici.doc(id).update(updates);
      return true;
    } catch (error) {
      console.error('Error updating putnik:', error);
      return false;
    }
  }

  async deletePutnik(id: string): Promise<boolean> {
    try {
      await this.putnici.doc(id).update({ obrisan: true });
      return true;
    } catch (error) {
      console.error('Error deleting putnik:', error);
      return false;
    }
  }

  // DNEVNI PUTNICI OPERATIONS

  async getDnevniPutnici(datum: string): Promise<any[]> {
    try {
      const snapshot = await this.dnevniPutnici.where('datum', '==', datum).get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      console.error('Error getting dnevni putnici:', error);
      return [];
    }
  }

  async addDnevniPutnik(data: DnevniPutnik): Promise<string> {
    try {
      const validatedData = DnevniPutnikSchema.parse(data);
      if (!validatedData.created_at) {
        validatedData.created_at = new Date().toISOString();
      }
      
      const docRef = await this.dnevniPutnici.add(validatedData);
      return docRef.id;
    } catch (error) {
      console.error('Error adding dnevni putnik:', error);
      throw error;
    }
  }

  async updateDnevniPutnik(id: string, updates: Partial<DnevniPutnik>): Promise<boolean> {
    try {
      await this.dnevniPutnici.doc(id).update(updates);
      return true;
    } catch (error) {
      console.error('Error updating dnevni putnik:', error);
      return false;
    }
  }

  async deleteDnevniPutnik(id: string): Promise<boolean> {
    try {
      await this.dnevniPutnici.doc(id).delete();
      return true;
    } catch (error) {
      console.error('Error deleting dnevni putnik:', error);
      return false;
    }
  }

  // GPS LOKACIJE OPERATIONS

  async getGpsLokacije(startDate: string, endDate: string, vozacId?: string): Promise<any[]> {
    try {
      let query = this.gpsLokacije
        .where('timestamp', '>=', startDate)
        .where('timestamp', '<=', endDate + 'T23:59:59.999Z');

      if (vozacId) {
        query = query.where('vozac_id', '==', vozacId);
      }

      const snapshot = await query.orderBy('timestamp', 'desc').get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      console.error('Error getting GPS lokacije:', error);
      return [];
    }
  }

  async addGpsLokacija(data: GpsLokacija): Promise<string> {
    try {
      const validatedData = GpsLokacijaSchema.parse(data);
      const docRef = await this.gpsLokacije.add(validatedData);
      return docRef.id;
    } catch (error) {
      console.error('Error adding GPS lokacija:', error);
      throw error;
    }
  }

  // STATISTICS OPERATIONS

  async getDailyStatistics(datum: string, vozacId?: string): Promise<any> {
    try {
      let query = this.dnevniPutnici.where('datum', '==', datum);
      
      if (vozacId) {
        query = query.where('vozac_id', '==', vozacId);
      }

      const snapshot = await query.get();
      const dnevniPutnici = snapshot.docs.map(doc => doc.data());

      const totalPassengers = dnevniPutnici.length;
      const totalRevenue = dnevniPutnici.reduce((sum, dp) => sum + (dp.cena_karte || 0), 0);
      const totalKusur = dnevniPutnici.reduce((sum, dp) => sum + (dp.kusur || 0), 0);
      const paidPassengers = dnevniPutnici.filter(dp => dp.placeno).length;
      const unpaidPassengers = totalPassengers - paidPassengers;

      const ticketTypeStats = dnevniPutnici.reduce((acc, dp) => {
        const tipKarte = dp.tip_karte || 'Unknown';
        acc[tipKarte] = (acc[tipKarte] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);

      return {
        datum,
        vozac_id: vozacId || 'all',
        total_passengers: totalPassengers,
        total_revenue: totalRevenue,
        total_kusur: totalKusur,
        paid_passengers: paidPassengers,
        unpaid_passengers: unpaidPassengers,
        ticket_type_stats: ticketTypeStats,
        average_ticket_price: totalPassengers > 0 ? totalRevenue / totalPassengers : 0,
      };
    } catch (error) {
      console.error('Error getting daily statistics:', error);
      return {};
    }
  }

  async getMonthlyStatistics(year: number, month: number, vozacId?: string): Promise<any> {
    try {
      const startDate = `${year}-${month.toString().padStart(2, '0')}-01`;
      const lastDay = new Date(year, month, 0).getDate();
      const endDate = `${year}-${month.toString().padStart(2, '0')}-${lastDay}`;

      let query = this.dnevniPutnici
        .where('datum', '>=', startDate)
        .where('datum', '<=', endDate);

      if (vozacId) {
        query = query.where('vozac_id', '==', vozacId);
      }

      const snapshot = await query.get();
      const dnevniPutnici = snapshot.docs.map(doc => doc.data());

      const totalPassengers = dnevniPutnici.length;
      const totalRevenue = dnevniPutnici.reduce((sum, dp) => sum + (dp.cena_karte || 0), 0);
      const totalKusur = dnevniPutnici.reduce((sum, dp) => sum + (dp.kusur || 0), 0);

      // Group by date for daily breakdown
      const dailyStats = dnevniPutnici.reduce((acc, dp) => {
        const datum = dp.datum;
        if (!acc[datum]) {
          acc[datum] = { passengers: 0, revenue: 0, kusur: 0 };
        }
        acc[datum].passengers += 1;
        acc[datum].revenue += dp.cena_karte || 0;
        acc[datum].kusur += dp.kusur || 0;
        return acc;
      }, {} as Record<string, { passengers: number; revenue: number; kusur: number }>);

      return {
        year,
        month,
        vozac_id: vozacId || 'all',
        total_passengers: totalPassengers,
        total_revenue: totalRevenue,
        total_kusur: totalKusur,
        daily_breakdown: dailyStats,
        average_daily_passengers: Object.keys(dailyStats).length > 0 ? totalPassengers / Object.keys(dailyStats).length : 0,
        average_daily_revenue: Object.keys(dailyStats).length > 0 ? totalRevenue / Object.keys(dailyStats).length : 0,
      };
    } catch (error) {
      console.error('Error getting monthly statistics:', error);
      return {};
    }
  }
}