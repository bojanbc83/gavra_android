import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

export class SecureFirebaseService {
  private readonly db: any;
  private readonly allowedCollections: string[];
  private readonly readOnlyMode: boolean;

  constructor(readOnlyMode = false) {
    try {
      const serviceAccount = require('../serviceAccountKey.json');
      
      initializeApp({
        credential: cert(serviceAccount),
      });

      this.db = getFirestore();
      this.readOnlyMode = readOnlyMode;
      
      // 🔐 OGRANIČI pristup samo ovim kolekcijama
      this.allowedCollections = [
        'putnici',
        'dnevni_putnici', 
        'vozaci',
        'rute',
        'gps_lokacije'
      ];
      
      console.log(`🔒 Secure Firebase Service initialized (readOnly: ${readOnlyMode})`);
    } catch (error) {
      console.error('🚨 Firebase initialization error:', error);
      throw error;
    }
  }

  // 🛡️ SIGURNOSNA PROVJERA
  private validateCollection(collection: string): boolean {
    if (!this.allowedCollections.includes(collection)) {
      throw new Error(`🚫 Access denied to collection: ${collection}`);
    }
    return true;
  }

  private validateOperation(operation: string): boolean {
    if (this.readOnlyMode && !['get', 'list', 'query'].includes(operation)) {
      throw new Error(`🚫 Write operations disabled in read-only mode: ${operation}`);
    }
    return true;
  }

  // 📖 SIGURNO ČITANJE
  async getDocument(collection: string, documentId: string) {
    this.validateCollection(collection);
    this.validateOperation('get');
    
    const doc = await this.db.collection(collection).doc(documentId).get();
    if (doc.exists) {
      return { id: doc.id, ...doc.data() };
    }
    return null;
  }

  // 📝 SIGURNO PISANJE (samo ako nije read-only)
  async setDocument(collection: string, documentId: string, data: any) {
    this.validateCollection(collection);
    this.validateOperation('set');
    
    // 🔍 DODATNE VALIDACIJE za kritične operacije
    if (collection === 'vozaci') {
      console.log(`🚨 CRITICAL: Writing to vozaci collection: ${documentId}`);
    }
    
    await this.db.collection(collection).doc(documentId).set(data);
    return true;
  }

  // 📊 SIGURNI UPITI (read-only operacije)
  async getDnevniPutnici(datum: string) {
    this.validateCollection('dnevni_putnici');
    this.validateOperation('query');
    
    const snapshot = await this.db
      .collection('dnevni_putnici')
      .where('datum', '==', datum)
      .get();
    
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }

  // 🚫 BLOKIRAJ OPASNE OPERACIJE
  async deleteDocument(collection: string, documentId: string) {
    throw new Error('🚫 DELETE operations are disabled for security');
  }

  async updateDocument(collection: string, documentId: string, data: any) {
    this.validateCollection(collection);
    this.validateOperation('update');
    
    console.log(`⚠️  UPDATE operation: ${collection}/${documentId}`);
    await this.db.collection(collection).doc(documentId).update(data);
    return true;
  }
}