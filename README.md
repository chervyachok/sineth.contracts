In complex transactions, where on-chain computation may exceed limits, off-chain methods are often used to compute proofs. 
However, on the Oasis Sapphire chain, unique features allow the secure storage of private signing keys directly in contract storage. 
This allows proof computation to be performed fully on-chain.

The Lowest Unique Bid Auction (LUB) was used as an example to demonstrate the utility of the method developed in the project.
In this scenario, where participants submit multiple bids, each bid must be checked to determine the winner. 
Since processing all bids in a single transaction is impractical (due to gas limits), the solution involves processing bids in batches, signing and verifying each batch sequentially. 
After multiple calls, the results can be consolidated to generate a final, verified proof on-chain.

The same batch-processing approach was also applied to check whether a user has at least one unique bid in the auction and whether the auction contains any unique bids at all.
