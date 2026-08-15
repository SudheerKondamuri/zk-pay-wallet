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

const contractAbi = [
  "event Deposited(address indexed user, uint256 amount, uint256 newBalance)",
  "event BatchCommitted(uint256 indexed batchIndex, bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, address relayer)",
  "event Withdrawn(address indexed user, uint256 amount)"
];

async function main() {
  console.log("Indexer starting...");
  let lastProcessedBlock = 0;

  while (true) {
    try {
      const addressesPath = getAddressesFilePath();
      if (!fs.existsSync(addressesPath)) {
        await new Promise(r => setTimeout(r, 2000));
        continue;
      }

      const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
      const rpcUrl = process.env.RPC_URL || addresses.rpcUrl || 'http://127.0.0.1:8545';
      const provider = new ethers.JsonRpcProvider(rpcUrl);
      const rollupContract = new ethers.Contract(addresses.ZKRollupPayments, contractAbi, provider);

      const currentBlock = await provider.getBlockNumber();
      if (currentBlock >= lastProcessedBlock) {
        const depositedEvents = await rollupContract.queryFilter("Deposited", lastProcessedBlock, currentBlock);
        for (const event of depositedEvents) {
          const log = event as ethers.EventLog;
          const user = log.args[0];
          const amount = log.args[1];
          console.log(`[INDEXER] Deposited: user=${user}, amount=${amount.toString()}`);
          await pool.query(
            `INSERT INTO deposits (user_address, amount_wei, tx_hash, block_number) VALUES ($1, $2, $3, $4)`,
            [user.toLowerCase(), amount.toString(), log.transactionHash, log.blockNumber]
          );
        }

        const batchEvents = await rollupContract.queryFilter("BatchCommitted", lastProcessedBlock, currentBlock);
        for (const event of batchEvents) {
          const log = event as ethers.EventLog;
          const batchIndex = log.args[0];
          const newStateRoot = log.args[1];
          const batchHash = log.args[2];
          const txCount = log.args[3];
          const relayer = log.args[4];
          console.log(`[INDEXER] BatchCommitted: index=${batchIndex.toString()}`);
          await pool.query(
            `INSERT INTO batches (batch_index, new_state_root, batch_hash, tx_count, relayer_address, committed_at, tx_hash) 
             VALUES ($1, $2, $3, $4, $5, NOW(), $6)
             ON CONFLICT (batch_index) DO UPDATE 
             SET committed_at = NOW(), tx_hash = $6`,
            [batchIndex.toString(), newStateRoot, batchHash, txCount.toString(), relayer.toLowerCase(), log.transactionHash]
          );
        }

        const withdrawalEvents = await rollupContract.queryFilter("Withdrawn", lastProcessedBlock, currentBlock);
        for (const event of withdrawalEvents) {
          const log = event as ethers.EventLog;
          const user = log.args[0];
          const amount = log.args[1];
          console.log(`[INDEXER] Withdrawn: user=${user}, amount=${amount.toString()}`);
          await pool.query(
            `INSERT INTO withdrawals (user_address, amount_wei, tx_hash, block_number) VALUES ($1, $2, $3, $4)`,
            [user.toLowerCase(), amount.toString(), log.transactionHash, log.blockNumber]
          );
        }

        lastProcessedBlock = currentBlock + 1;
      }
    } catch (e: any) {
      console.error("Indexer polling error:", e.message || e);
    }
    await new Promise(r => setTimeout(r, 1000));
  }
}

main().catch(console.error);
