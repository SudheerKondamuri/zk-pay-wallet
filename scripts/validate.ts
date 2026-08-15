import { ethers } from "ethers";
import axios from "axios";
import fs from "fs";

const API_URL = process.env.API_URL || "http://localhost:4000";
const RPC_URL = process.env.RPC_URL || "http://localhost:8545";

const USER_A_PRIVATE_KEY = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const USER_A_ADDRESS = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

interface TestResult {
  test: string;
  status: "passed" | "failed";
  detail: string;
}

interface ValidationReport {
  passed: number;
  failed: number;
  results: TestResult[];
}

async function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function validate() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(USER_A_PRIVATE_KEY, provider);

  const report: ValidationReport = { passed: 0, failed: 0, results: [] };

  function addResult(test: string, status: "passed" | "failed", detail: string) {
    report.results.push({ test, status, detail });
    if (status === "passed") report.passed++;
    else report.failed++;
    console.log(`[${status.toUpperCase()}] ${test} - ${detail}`);
  }

  try {
    const stateRes = await axios.get(`${API_URL}/state`);
    const contractAddress = stateRes.data.contractAddress;

    const contractAbi = [
      "function deposit() payable",
    ];
    const rollup = new ethers.Contract(contractAddress, contractAbi, wallet);

    console.log("Depositing 0.5 ETH for User A...");
    const tx = await rollup.deposit({ value: ethers.parseEther("0.5") });
    await tx.wait();

    let depositFound = false;
    for (let i = 0; i < 20; i++) {
      const res = await axios.get(`${API_URL}/deposits/${USER_A_ADDRESS}`);
      if (res.data && BigInt(res.data.balanceWei) > 0n) {
        depositFound = true;
        break;
      }
      await sleep(1000);
    }
    
    if (depositFound) {
      addResult("Deposit indexer", "passed", "Deposit successfully indexed.");
    } else {
      addResult("Deposit indexer", "failed", "Deposit not found by indexer after timeout.");
    }

    try {
      await axios.post(`${API_URL}/intents`, {
        fromAddress: USER_A_ADDRESS,
        toAddress: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
        amountWei: ethers.parseEther("999").toString()
      });
      addResult("Invalid intent validation", "failed", "Accepted invalid amount.");
    } catch (e: any) {
      if (e.response && e.response.status === 400) {
        addResult("Invalid intent validation", "passed", "Rejected invalid amount appropriately.");
      } else {
        addResult("Invalid intent validation", "failed", "Failed with unexpected error: " + e.message);
      }
    }

    const intentRes = await axios.post(`${API_URL}/intents`, {
      fromAddress: USER_A_ADDRESS,
      toAddress: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
      amountWei: ethers.parseEther("0.1").toString()
    });
    
    addResult("Valid intent submission", "passed", "Successfully submitted valid intent.");
    
    let isBatched = false;
    for (let i = 0; i < 30; i++) {
      const listRes = await axios.get(`${API_URL}/intents?address=${USER_A_ADDRESS}`);
      const intent = listRes.data.intents.find((item: any) => item.id === intentRes.data.intentId);
      if (intent && (intent.status === 'batched' || intent.status === 'committed')) {
        isBatched = true;
        break;
      }
      await sleep(1000);
    }

    if (isBatched) {
      addResult("Relayer batching", "passed", "Relayer successfully processed intent.");
    } else {
      addResult("Relayer batching", "failed", "Intent not batched after timeout.");
    }

    const batchesRes = await axios.get(`${API_URL}/batches`);
    if (batchesRes.data.batches && batchesRes.data.batches.length > 0) {
      addResult("Batch retrieval", "passed", "Successfully retrieved batches.");
    } else {
      addResult("Batch retrieval", "failed", "No batches returned.");
    }

  } catch (err: any) {
    addResult("Validation script", "failed", err.message);
  }

  fs.writeFileSync("validation_report.json", JSON.stringify(report, null, 2));

  if (report.failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

validate();
