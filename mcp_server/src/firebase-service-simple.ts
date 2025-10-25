import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

export class FirebaseService {
  private db: any;
  private auth: any;

  constructor() {
    try {
      const serviceAccount = require('../serviceAccountKey.json');
      
      initializeApp({
        credential: cert(serviceAccount),
      });

      this.db = getFirestore();
      this.auth = getAuth();
      console.log('Firebase initialized successfully');
    } catch (error) {
      console.error('Firebase initialization error:', error);
      throw error;
    }
  }

  async getDocument(collection: string, documentId: string) {
    const doc = await this.db.collection(collection).doc(documentId).get();
    if (doc.exists) {
      return { id: doc.id, ...doc.data() };
    }
    return null;
  }

  async setDocument(collection: string, documentId: string, data: any) {
    await this.db.collection(collection).doc(documentId).set(data);
    return true;
  }

  async getDnevniPutnici(datum: string) {
    const snapshot = await this.db
      .collection('dnevni_putnici')
      .where('datum', '==', datum)
      .get();
    
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }

  async getCollection(collectionName: string) {
    const snapshot = await this.db.collection(collectionName).get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }
}