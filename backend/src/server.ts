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

let provider: ethers.JsonRpcProvider;

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

function getRollupContract(): ethers.Contract {
  const addressesPath = getAddressesFilePath();
  if (!fs.existsSync(addressesPath)) {
    throw new Error('addresses.json not found');
  }
  const addresses = JSON.parse(fs.readFileSync(addressesPath, 'utf8'));
  const rpcUrl = process.env.RPC_URL || addresses.rpcUrl || 'http://127.0.0.1:8545';
  if (!provider) {
    provider = new ethers.JsonRpcProvider(rpcUrl);
  }
  
  const contractAbi = [
    "function deposits(address) view returns (uint256)",
    "function currentStateRoot() view returns (bytes32)",
    "function batchCount() view returns (uint256)",
    "function withdrawTo(address recipient, uint256 amount) external"
  ];
  
  return new ethers.Contract(addresses.ZKRollupPayments, contractAbi, provider);
}

app.post('/intents', async (req, res) => {
  try {
    const { fromAddress, toAddress, amountWei } = req.body;
    
    // Calculate L2 Balance from DB
    const depositResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_deposits FROM deposits WHERE LOWER(user_address) = LOWER($1)`,
      [fromAddress]
    );
    const totalDeposits = BigInt(depositResult.rows[0].total_deposits);

    const withdrawalResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_withdrawals FROM withdrawals WHERE LOWER(user_address) = LOWER($1)`,
      [fromAddress]
    );
    const totalWithdrawals = BigInt(withdrawalResult.rows[0].total_withdrawals);

    const sentResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_sent FROM payment_intents WHERE LOWER(from_address) = LOWER($1)`,
      [fromAddress]
    );
    const totalSent = BigInt(sentResult.rows[0].total_sent);

    const receivedResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_received FROM payment_intents WHERE LOWER(to_address) = LOWER($1)`,
      [fromAddress]
    );
    const totalReceived = BigInt(receivedResult.rows[0].total_received);

    const l2Balance = totalDeposits + totalReceived - totalWithdrawals - totalSent;

    if (BigInt(amountWei) > l2Balance) {
      return res.status(400).json({ error: 'Insufficient L2 balance' });
    }
    
    const result = await pool.query(
      `INSERT INTO payment_intents (from_address, to_address, amount_wei, status) 
       VALUES ($1, $2, $3, 'pending') RETURNING id`,
      [fromAddress.toLowerCase(), toAddress.toLowerCase(), amountWei]
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
      query += ` AND (LOWER(from_address) = LOWER($${params.length}) OR LOWER(to_address) = LOWER($${params.length}))`;
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
    const depositsResult = await pool.query('SELECT * FROM deposits WHERE batch_id = $1', [batchIndex]);
    const withdrawalsResult = await pool.query('SELECT * FROM withdrawals WHERE batch_id = $1', [batchIndex]);
    
    if (batchResult.rows.length === 0) {
      return res.status(404).json({ error: 'Batch not found' });
    }
    
    res.json({ 
      batch: batchResult.rows[0], 
      intents: intentsResult.rows,
      deposits: depositsResult.rows,
      withdrawals: withdrawalsResult.rows
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/deposits/:address', async (req, res) => {
  try {
    const { address } = req.params;
    
    // Calculate L2 Balance from DB
    const depositResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_deposits FROM deposits WHERE LOWER(user_address) = LOWER($1)`,
      [address]
    );
    const totalDeposits = BigInt(depositResult.rows[0].total_deposits);

    const withdrawalResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_withdrawals FROM withdrawals WHERE LOWER(user_address) = LOWER($1)`,
      [address]
    );
    const totalWithdrawals = BigInt(withdrawalResult.rows[0].total_withdrawals);

    const sentResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_sent FROM payment_intents WHERE LOWER(from_address) = LOWER($1)`,
      [address]
    );
    const totalSent = BigInt(sentResult.rows[0].total_sent);

    const receivedResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_received FROM payment_intents WHERE LOWER(to_address) = LOWER($1)`,
      [address]
    );
    const totalReceived = BigInt(receivedResult.rows[0].total_received);

    const l2Balance = totalDeposits + totalReceived - totalWithdrawals - totalSent;

    res.json({ 
      address, 
      balanceWei: l2Balance.toString(),
      balanceEth: ethers.formatEther(l2Balance)
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/withdrawals', async (req, res) => {
  try {
    const { userAddress, amountWei } = req.body;
    if (!userAddress || !amountWei) {
      return res.status(400).json({ error: 'userAddress and amountWei are required' });
    }

    if (BigInt(amountWei) <= 0n) {
      return res.status(400).json({ error: 'Amount must be greater than 0' });
    }

    // Calculate L2 Balance from DB
    const depositResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_deposits FROM deposits WHERE LOWER(user_address) = LOWER($1)`,
      [userAddress]
    );
    const totalDeposits = BigInt(depositResult.rows[0].total_deposits);

    const withdrawalResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_withdrawals FROM withdrawals WHERE LOWER(user_address) = LOWER($1)`,
      [userAddress]
    );
    const totalWithdrawals = BigInt(withdrawalResult.rows[0].total_withdrawals);

    const sentResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_sent FROM payment_intents WHERE LOWER(from_address) = LOWER($1)`,
      [userAddress]
    );
    const totalSent = BigInt(sentResult.rows[0].total_sent);

    const receivedResult = await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) as total_received FROM payment_intents WHERE LOWER(to_address) = LOWER($1)`,
      [userAddress]
    );
    const totalReceived = BigInt(receivedResult.rows[0].total_received);

    const l2Balance = totalDeposits + totalReceived - totalWithdrawals - totalSent;

    if (BigInt(amountWei) > l2Balance) {
      return res.status(400).json({ error: 'Insufficient L2 balance for withdrawal' });
    }

    const contract = getRollupContract();
    const targetAddress = await contract.getAddress();
    const contractEthBalance = await provider.getBalance(targetAddress);
    if (contractEthBalance < BigInt(amountWei)) {
      return res.status(400).json({ 
        error: `Vault contract liquidity (${ethers.formatEther(contractEthBalance)} ETH) is insufficient for this withdrawal.` 
      });
    }

    const relayerPk = process.env.RELAYER_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    const relayerWallet = new ethers.Wallet(relayerPk, provider);
    
    const contractWithRelayer = contract.connect(relayerWallet) as ethers.Contract;
    const tx = await contractWithRelayer.withdrawTo(userAddress, BigInt(amountWei));
    const receipt = await tx.wait();

    // Insert directly into withdrawals table so balance updates immediately
    await pool.query(
      `INSERT INTO withdrawals (user_address, amount_wei, tx_hash, block_number) 
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (tx_hash) DO NOTHING`,
      [userAddress.toLowerCase(), amountWei.toString(), receipt.hash, receipt.blockNumber]
    );

    res.status(200).json({
      status: 'confirmed',
      userAddress,
      amountWei,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
    });
  } catch (error: any) {
    console.error('Withdrawal error:', error);
    res.status(500).json({ error: error.message || 'Withdrawal execution failed' });
  }
});

app.get('/withdrawals/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const result = await pool.query(
      `SELECT * FROM withdrawals WHERE LOWER(user_address) = LOWER($1) ORDER BY id DESC`,
      [address]
    );
    res.json({ withdrawals: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/state', async (req, res) => {
  try {
    const contract = getRollupContract();
    const currentStateRoot = await contract.currentStateRoot();
    const batchCount = await contract.batchCount();
    const targetAddress = await contract.getAddress();
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
  const migrationsPath = path.join(__dirname, '..', 'migrations', '01-init.sql');
  const sql = fs.readFileSync(migrationsPath, 'utf8');
  await pool.query(sql);
  console.log('Database migrations applied successfully.');
}

const PORT = process.env.PORT || 4000;
async function startServer() {
  await runMigrations();
  
  app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`Express API listening on port ${PORT}`);
  });
}

startServer().catch(console.error);
