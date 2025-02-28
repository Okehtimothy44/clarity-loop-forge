import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create new app as contract owner",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "create-app",
        [types.ascii("Test App")],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "Can register new device",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    // First create an app
    let block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "create-app",
        [types.ascii("Test App")],
        wallet_1.address
      )
    ]);
    
    // Then register device
    block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "register-device",
        [
          types.ascii("device-001"),
          types.uint(1),
          types.utf8("{'type': 'sensor'}")
        ],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "Cannot register device for non-existent app",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "register-device",
        [
          types.ascii("device-001"),
          types.uint(999),
          types.utf8("{'type': 'sensor'}")
        ],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectErr(104); // err-invalid-app
  }
});

Clarinet.test({
  name: "Can deactivate owned device",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    // Setup: Create app and register device
    let block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "create-app",
        [types.ascii("Test App")],
        wallet_1.address
      ),
      Tx.contractCall(
        "loop-forge",
        "register-device",
        [
          types.ascii("device-001"),
          types.uint(1),
          types.utf8("{'type': 'sensor'}")
        ],
        wallet_1.address
      )
    ]);
    
    // Deactivate device
    block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "deactivate-device",
        [types.ascii("device-001")],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
