// [Previous test content remains, adding new tests...]

Clarinet.test({
  name: "Can update device metadata",
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
    
    // Update metadata
    block = chain.mineBlock([
      Tx.contractCall(
        "loop-forge",
        "update-device-metadata",
        [
          types.ascii("device-001"),
          types.utf8("{'type': 'sensor', 'version': '2.0'}")
        ],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

// [Additional tests for rate limiting and event querying...]
