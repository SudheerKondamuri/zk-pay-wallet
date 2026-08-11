import express from 'express';
import cors from 'cors';
import { ethers } from 'ethers';
import pkg from 'pg';
const { Pool } = pkg;
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'password',
  database: process.env.POSTGRES_DB || 'rollup_db',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
});

let rollupContract: ethers.Contract;
let provider: ethers.JsonRpcProvider;

async function setupEthers() {
  const addressesPath = path.join(__dirname, '..', '..', 'deployments', 'addresses.json');
  if (!fs.existsSync(addressesPath)) {
    console.error('addresses.json not found!');
    return;
  }
  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  const rpcUrl = process.env.RPC_URL || addresses.rpcUrl || 'http://127.0.0.1:8545';
  provider = new ethers.JsonRpcProvider(rpcUrl);
  
  const contractAbi = [
    "function deposits(address) view returns (uint256)",
    "function currentStateRoot() view returns (bytes32)",
    "function batchCount() view returns (uint256)"
  ];
  
  rollupContract = new ethers.Contract(addresses.ZKRollupPayments, contractAbi, provider);
}

app.post('/intents', async (req, res) => {
  try {
    const { fromAddress, toAddress, amountWei } = req.body;
    
    // Check on-chain balance
    const onChainBalance = await rollupContract.deposits(fromAddress);
    if (BigInt(amountWei) > onChainBalance) {
      return res.status(400).json({ error: 'Insufficient on-chain deposit' });
    }
    
    const result = await pool.query(
      `INSERT INTO payment_intents (from_address, to_address, amount_wei, status) 
       VALUES ($1, $2, $3, 'pending') RETURNING id`,
      [fromAddress, toAddress, amountWei]
    );
    
    res.status(201).json({ intentId: result.rows[0].id, status: 'pending' });
  } catch (error: any) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/intents', async (req, res) => {
  try {
    const { address, status } = req.query;
    let query = 'SELECT * FROM payment_intents WHERE 1=1';
    const params: any[] = [];
    
    if (address) {
      params.push(address);
      query += ` AND from_address = $${params.length}`;
    }
    if (status) {
      params.push(status);
      query += ` AND status = $${params.length}`;
    }
    
    const result = await pool.query(query, params);
    res.json({ intents: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/batches', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM batches ORDER BY batch_index DESC');
    res.json({ batches: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/batches/:batchIndex', async (req, res) => {
  try {
    const { batchIndex } = req.params;
    const batchResult = await pool.query('SELECT * FROM batches WHERE batch_index = $1', [batchIndex]);
    const intentsResult = await pool.query('SELECT * FROM payment_intents WHERE batch_id = $1', [batchIndex]);
    
    if (batchResult.rows.length === 0) {
      return res.status(404).json({ error: 'Batch not found' });
    }
    
    res.json({ batch: batchResult.rows[0], intents: intentsResult.rows });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/deposits/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const balanceWei = await rollupContract.deposits(address);
    res.json({ 
      address, 
      balanceWei: balanceWei.toString(),
      balanceEth: ethers.formatEther(balanceWei)
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/state', async (req, res) => {
  try {
    const currentStateRoot = await rollupContract.currentStateRoot();
    const batchCount = await rollupContract.batchCount();
    const targetAddress = await rollupContract.getAddress();
    res.json({ 
      currentStateRoot, 
      batchCount: Number(batchCount), 
      contractAddress: targetAddress 
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

async function runMigrations() {
  const migrationsPath = path.join(__dirname, '..', '..', 'migrations', '01-init.sql');
  const sql = fs.readFileSync(migrationsPath, 'utf8');
  await pool.query(sql);
  console.log('Database migrations applied successfully.');
}

const PORT = process.env.PORT || 4000;
async function startServer() {
  await runMigrations();
  await setupEthers();
  
  app.listen(PORT, () => {
    console.log(`Express API listening on port ${PORT}`);
  });
}

startServer().catch(console.error);
