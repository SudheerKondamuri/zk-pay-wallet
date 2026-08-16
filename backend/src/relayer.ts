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

function getAddressesFilePath(): string {
  const candidatePaths = [
    path.join(process.cwd(), 'deployments', 'addresses.json'),
    path.join(__dirname, '..', 'deployments', 'addresses.json'),
    path.join(__dirname, '..', '..', 'deployments', 'addresses.json'),
    '/app/deployments/addresses.json'
  ];
  for (const p of candidatePaths) {
    if (fs.existsSync(p)) return p;
  }
  return candidatePaths[0];
}

async function getProviderAndContract() {
  const addressesPath = getAddressesFilePath();
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
    const intentsRes = await pool.query(
      `SELECT * FROM payment_intents WHERE status = 'pending' ORDER BY created_at ASC LIMIT 10 FOR UPDATE SKIP LOCKED`
    );
    const depositsRes = await pool.query(
      `SELECT * FROM deposits WHERE batch_id IS NULL ORDER BY indexed_at ASC LIMIT 10 FOR UPDATE SKIP LOCKED`
    );
    const withdrawalsRes = await pool.query(
      `SELECT * FROM withdrawals WHERE batch_id IS NULL ORDER BY indexed_at ASC LIMIT 10 FOR UPDATE SKIP LOCKED`
    );

    const totalCount = intentsRes.rows.length + depositsRes.rows.length + withdrawalsRes.rows.length;
    if (totalCount === 0) return;

    console.log(
      `[RELAYER] Found ${intentsRes.rows.length} intents, ${depositsRes.rows.length} deposits, ${withdrawalsRes.rows.length} withdrawals to batch`
    );

    const { contract, wallet } = await getProviderAndContract();

    let concatIds = "0x";
    for (const intent of intentsRes.rows) {
      concatIds += Buffer.from(intent.id.replace(/-/g, '')).toString('hex');
    }
    for (const dep of depositsRes.rows) {
      concatIds += Buffer.from(`dep_${dep.id}_${dep.tx_hash}`).toString('hex');
    }
    for (const wd of withdrawalsRes.rows) {
      concatIds += Buffer.from(`wd_${wd.id}_${wd.tx_hash}`).toString('hex');
    }

    const batchHash = ethers.keccak256(concatIds);
    const oldRoot = await contract.currentStateRoot();
    const newStateRoot = ethers.keccak256(
      ethers.solidityPacked(['bytes32', 'bytes32'], [oldRoot, batchHash])
    );

    const tx = await contract.commitBatch(newStateRoot, batchHash, totalCount, "0x", []);
    const receipt = await tx.wait();

    const batchIndex = await contract.batchCount() - 1n;

    if (intentsRes.rows.length > 0) {
      const intentIds = intentsRes.rows.map((i: any) => i.id);
      await pool.query(
        `UPDATE payment_intents SET status = 'batched', batch_id = $1, updated_at = NOW() WHERE id = ANY($2)`,
        [batchIndex.toString(), intentIds]
      );
    }

    if (depositsRes.rows.length > 0) {
      const depositIds = depositsRes.rows.map((d: any) => d.id);
      await pool.query(
        `UPDATE deposits SET batch_id = $1 WHERE id = ANY($2)`,
        [batchIndex.toString(), depositIds]
      );
    }

    if (withdrawalsRes.rows.length > 0) {
      const withdrawalIds = withdrawalsRes.rows.map((w: any) => w.id);
      await pool.query(
        `UPDATE withdrawals SET batch_id = $1 WHERE id = ANY($2)`,
        [batchIndex.toString(), withdrawalIds]
      );
    }

    await pool.query(
      `INSERT INTO batches (batch_index, old_state_root, new_state_root, batch_hash, tx_count, relayer_address, tx_hash) 
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (batch_index) DO UPDATE 
       SET old_state_root = EXCLUDED.old_state_root, tx_count = EXCLUDED.tx_count`,
      [batchIndex.toString(), oldRoot, newStateRoot, batchHash, totalCount, wallet.address, receipt.hash]
    );

    console.log(
      `[RELAYER] Batch committed successfully. Batch index: ${batchIndex}, New State Root: ${newStateRoot}`
    );
  } catch (e: any) {
    console.error("[RELAYER] Error during batch commit:", e);
  }
}

async function main() {
  console.log("Relayer started...");
  setInterval(runRelayer, 4000);
}

main().catch(console.error);
