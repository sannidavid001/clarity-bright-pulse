import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can submit and retrieve an idea",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'submit-idea',
                [
                    types.ascii("Test Idea"),
                    types.utf8("This is a test idea description")
                ],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0); // First idea should have ID 0
        
        let getBlock = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'get-idea',
                [types.uint(0)],
                wallet1.address
            )
        ]);
        
        const idea = getBlock.receipts[0].result.expectOk().expectSome();
        assertEquals(idea.author, wallet1.address);
        assertEquals(idea.votes, types.uint(0));
    }
});

Clarinet.test({
    name: "Can vote on idea and receive points",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Submit idea
        let block = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'submit-idea',
                [
                    types.ascii("Test Idea"),
                    types.utf8("Description")
                ],
                wallet1.address
            )
        ]);
        
        // Vote on idea
        let voteBlock = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'vote-on-idea',
                [types.uint(0)],
                wallet2.address
            )
        ]);
        
        voteBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check points
        let pointsBlock = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'get-user-points',
                [types.principal(wallet2.address)],
                wallet2.address
            )
        ]);
        
        pointsBlock.receipts[0].result.expectOk().expectUint(10); // Default reward is 10
    }
});

Clarinet.test({
    name: "Cannot vote twice on same idea",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Submit idea
        chain.mineBlock([
            Tx.contractCall('bright_pulse', 'submit-idea',
                [
                    types.ascii("Test Idea"),
                    types.utf8("Description")
                ],
                wallet1.address
            )
        ]);
        
        // Vote twice
        let block = chain.mineBlock([
            Tx.contractCall('bright_pulse', 'vote-on-idea',
                [types.uint(0)],
                wallet1.address
            ),
            Tx.contractCall('bright_pulse', 'vote-on-idea',
                [types.uint(0)],
                wallet1.address
            )
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr(types.uint(102)); // err-already-voted
    }
});