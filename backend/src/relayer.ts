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

async function getProviderAndContract() {
  const addressesPath = path.join(__dirname, '..', '..', 'deployments', 'addresses.json');
  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  const rpcUrl = process.env.RPC_URL || addresses.rpcUrl || 'http://127.0.0.1:8545';
  
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const privateKey = process.env.RELAYER_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const wallet = new ethers.Wallet(privateKey, provider);
  
  const contractAbi = [
    "function currentStateRoot() view returns (bytes32)",
    "function commitBatch(bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, bytes calldata proof, uint256[] calldata publicInputs) external",
    "function batchCount() view returns (uint256)"
  ];
  
  const contract = new ethers.Contract(addresses.ZKRollupPayments, contractAbi, wallet);
  return { contract, wallet };
}

async function runRelayer() {
  try {
    const res = await pool.query(`SELECT * FROM payment_intents WHERE status = 'pending' ORDER BY created_at ASC LIMIT 10 FOR UPDATE SKIP LOCKED`);
    if (res.rows.length === 0) return;
    
    const intents = res.rows;
    console.log(`[RELAYER] Found ${intents.length} pending intents`);
    
    const { contract, wallet } = await getProviderAndContract();
    
    let concatIds = "0x";
    for (const intent of intents) {
      concatIds += Buffer.from(intent.id.replace(/-/g, '')).toString('hex');
    }
    const batchHash = ethers.keccak256(concatIds);
    
    const oldRoot = await contract.currentStateRoot();
    
    const newStateRoot = ethers.keccak256(
      ethers.solidityPacked(['bytes32', 'bytes32'], [oldRoot, batchHash])
    );
    
    const tx = await contract.commitBatch(newStateRoot, batchHash, intents.length, "0x", []);
    const receipt = await tx.wait();
    
    const batchIndex = await contract.batchCount() - 1n;
    
    const intentIds = intents.map(i => i.id);
    await pool.query(
      `UPDATE payment_intents SET status = 'batched', batch_id = $1, updated_at = NOW() WHERE id = ANY($2)`,
      [batchIndex.toString(), intentIds]
    );
    
    await pool.query(
      `INSERT INTO batches (batch_index, old_state_root, new_state_root, batch_hash, tx_count, relayer_address, tx_hash) 
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (batch_index) DO UPDATE 
       SET old_state_root = EXCLUDED.old_state_root, tx_count = EXCLUDED.tx_count`,
      [batchIndex.toString(), oldRoot, newStateRoot, batchHash, intents.length, wallet.address, receipt.hash]
    );
    
    console.log(`[RELAYER] Batch committed successfully. Batch index: ${batchIndex}`);
  } catch (e: any) {
    console.error("[RELAYER] Error during batch commit:", e);
  }
}

async function main() {
  console.log("Relayer started...");
  setInterval(runRelayer, 15000);
}

main().catch(console.error);
