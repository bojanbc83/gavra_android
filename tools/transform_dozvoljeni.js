const fs = require('fs');
const path = require('path');

function parseCsvLine(line) {
  const result = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          cur += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur += ch;
      }
    } else {
      if (ch === ',') {
        result.push(cur);
        cur = '';
      } else if (ch === '"') {
        inQuotes = true;
      } else {
        cur += ch;
      }
    }
  }
  result.push(cur);
  return result;
}

function sqlEscape(val) {
  if (val === null || val === undefined) return 'NULL';
  return "'" + String(val).replace(/'/g, "''") + "'";
}

const input = path.join(__dirname, '..', 'tmp', 'dozvoljeni_mesecni_putnici_rows.csv');
const outSql = path.join(__dirname, '..', 'tmp', 'import_dozvoljeni.sql');
const outMapping = path.join(__dirname, '..', 'tmp', 'mapping_putovanja.sql');

if (!fs.existsSync(input)) {
  console.error('Input CSV not found:', input);
  process.exit(2);
}

const data = fs.readFileSync(input, 'utf8').trim().split(/\r?\n/);
if (data.length < 2) {
  console.error('CSV appears empty or missing rows');
  process.exit(2);
}

const header = parseCsvLine(data[0]).map(h => h.trim());
const rows = data.slice(1).map(parseCsvLine);

const insertLines = [];
for (const cols of rows) {
  const obj = {};
  for (let i = 0; i < header.length; i++) {
    obj[header[i]] = cols[i] !== undefined && cols[i] !== '' ? cols[i] : null;
  }

  // Map CSV -> columns that actually exist in `dozvoljeni_mesecni_putnici` migration
  const id = obj['id'] || null;
  const ime = obj['ime'] || null;
  const prezime = obj['prezime'] || null;
  const telefon = obj['telefon'] || null;
  const email = obj['email'] || null;
  const canonical_hash = obj['canonical_hash'] || null;
  // source_mesecni_putnici_id may be provided as comma-separated ids in CSV
  const source_ids_raw = obj['source_mesecni_putnici_id'] || null;
  let source_arr = null;
  if (source_ids_raw) {
    // normalize to SQL array literal
    const parts = String(source_ids_raw).split(/\s*[,;]\s*/).filter(Boolean);
    if (parts.length > 0) {
      source_arr = "ARRAY[" + parts.map(p => sqlEscape(p)).join(',') + "]::text[]";
    }
  }

  const colsList = [
    'id',
    'ime',
    'prezime',
    'telefon',
    'email',
    'canonical_hash',
    'source_mesecni_putnici_id',
    'created_at',
    'updated_at'
  ];

  const vals = [
    id ? sqlEscape(id) : 'gen_random_uuid()',
    ime ? sqlEscape(ime) : 'NULL',
    prezime ? sqlEscape(prezime) : 'NULL',
    telefon ? sqlEscape(telefon) : 'NULL',
    email ? sqlEscape(email) : 'NULL',
    canonical_hash ? sqlEscape(canonical_hash) : 'NULL',
    source_arr ? source_arr : 'NULL',
    obj['created_at'] ? sqlEscape(obj['created_at']) : 'now()',
    obj['updated_at'] ? sqlEscape(obj['updated_at']) : 'now()'
  ];

  insertLines.push(`INSERT INTO public.dozvoljeni_mesecni_putnici (${colsList.join(',')}) VALUES (${vals.join(',')});`);
}

fs.writeFileSync(outSql, insertLines.join('\n') + '\n', 'utf8');
console.log('Wrote', outSql, 'with', insertLines.length, 'INSERT statements');

// Generate mapping SQL to link putovanja_istorija rows by putnik_ime + datum
// Strategy: for each putnik from CSV, create an UPDATE that sets mesecni_putnik_id
// for putovanja_istorija rows with matching putnik_ime and datum.
const mappingLines = [];
for (const cols of rows) {
  const obj = {};
  for (let i = 0; i < header.length; i++) {
    obj[header[i]] = cols[i] !== undefined && cols[i] !== '' ? cols[i] : null;
  }
  const ime = obj['ime'] || '';
  const prezime = obj['prezime'] || '';
  const fullName = (ime + (prezime ? ' ' + prezime : '')).trim();
  const idVal = obj['id'] ? obj['id'] : null;
  if (!idVal || !fullName) continue;

  // Use a safe UPDATE that maps roster id into dozvoljeni_putnik_id on putovanja_istorija
  mappingLines.push(`-- Map roster putnik \"${fullName}\" (dozv id=${idVal}) to putovanja_istorija rows`);
  mappingLines.push(`UPDATE public.putovanja_istorija SET dozvoljeni_putnik_id = '${idVal}' WHERE putnik_ime = ${sqlEscape(fullName)};`);
  mappingLines.push('');
}

if (mappingLines.length > 0) {
  fs.writeFileSync(outMapping, mappingLines.join('\n') + '\n', 'utf8');
  console.log('Wrote mapping SQL to', outMapping);
} else {
  console.log('No mapping lines generated (missing ids or names)');
}
