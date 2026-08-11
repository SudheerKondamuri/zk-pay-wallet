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

const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'localhost',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'password',
  database: process.env.POSTGRES_DB || 'rollup_db',
  port: parseInt(process.env.POSTGRES_PORT || '5432'),
});

async function main() {
  const addressesPath = path.join(__dirname, '..', '..', 'deployments', 'addresses.json');
  
  while (!fs.existsSync(addressesPath)) {
    console.log('Waiting for addresses.json...');
    await new Promise(r => setTimeout(r, 2000));
  }
  
  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  const rpcUrl = process.env.RPC_URL || addresses.rpcUrl || 'http://127.0.0.1:8545';
  
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  
  while (true) {
    try {
      await provider.getNetwork();
      break;
    } catch (e) {
      console.log('Waiting for RPC node...');
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  const contractAbi = [
    "event Deposited(address indexed user, uint256 amount, uint256 newBalance)",
    "event BatchCommitted(uint256 indexed batchIndex, bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, address relayer)",
    "event Withdrawn(address indexed user, uint256 amount)"
  ];
  
  const rollupContract = new ethers.Contract(addresses.ZKRollupPayments, contractAbi, provider);

  rollupContract.on("Deposited", async (user, amount, newBalance, event) => {
    console.log(`[INDEXER] Deposited: user=${user}, amount=${amount.toString()}`);
    try {
      await pool.query(
        `INSERT INTO deposits (user_address, amount_wei, tx_hash, block_number) VALUES ($1, $2, $3, $4)`,
        [user, amount.toString(), event.log.transactionHash, event.log.blockNumber]
      );
    } catch (e) {
      console.error("Indexer deposit error:", e);
    }
  });

  rollupContract.on("BatchCommitted", async (batchIndex, newStateRoot, batchHash, txCount, relayer, event) => {
    console.log(`[INDEXER] BatchCommitted: index=${batchIndex.toString()}`);
    try {
      await pool.query(
        `INSERT INTO batches (batch_index, new_state_root, batch_hash, tx_count, relayer_address, committed_at, tx_hash) 
         VALUES ($1, $2, $3, $4, $5, NOW(), $6)
         ON CONFLICT (batch_index) DO UPDATE 
         SET committed_at = NOW(), tx_hash = $6`,
        [batchIndex.toString(), newStateRoot, batchHash, txCount.toString(), relayer, event.log.transactionHash]
      );
    } catch (e) {
      console.error("Indexer batch error:", e);
    }
  });

  rollupContract.on("Withdrawn", async (user, amount) => {
    console.log(`[WITHDRAW] address=${user} amount=${amount.toString()}`);
  });

  console.log("Indexer started...");
}

main().catch(console.error);
