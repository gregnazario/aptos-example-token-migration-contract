# aptos-example-burn-contract

This is an example of how someone would migrate from token V1 to token V2.

Simply just requires the address of the old collection, and then the rest goes as follows.  This does not:
1. Port over any properties (those all need to be handled manually)
2. Copy any permissions (all permissions are set to open)
3. Set royalties (royalties are set to 0)
4. Actually burn the NFTs, if you're the owner of the original contract, it's a lot easier to burn them then.
