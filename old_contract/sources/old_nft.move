/// An example of an older contract that doesn't have burn enabled, which can make it really hard to upgrade
/// or the original owner might not give access to it.
module original_contract::old_nft {

    use std::signer;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::object;
    use aptos_token::token;
    use aptos_token::token::{create_token_mutability_config, create_tokendata, direct_transfer};

    /// Not authorized, caller is not the creator of the contract
    const ENOT_CREATOR: u64 = 1;
    /// Not authorized, minting is frozen
    const EMINTING_FROZEN: u64 = 2;

    const COLLECTION_NAME: vector<u8> = b"Sleepy Crows";
    const COLLECTION_URI: vector<u8> = b"https://www.sleepycrows.com";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Old collection with not much happening";
    const MAX_SUPPLY: u64 = 1000000;

    const MUTABILITY_CONFIG: vector<bool> = vector[true, true, true, true, true];

    struct CollectionController has key {
        signer_cap: SignerCapability,
        count: u64,
        freeze_mint: bool,
    }

    entry fun freeze_mint(creator: &signer, freeze: bool) acquires CollectionController {
        // Simple access control
        assert!(signer::address_of(creator) == @original_contract, ENOT_CREATOR);

        let controller_object_address = object::create_object_address(&@original_contract, COLLECTION_NAME);
        let controller = borrow_global_mut<CollectionController>(controller_object_address);
        controller.freeze_mint = freeze;
    }

    entry fun init(creator: &signer) {
        // Simple access control
        assert!(signer::address_of(creator) == @original_contract, ENOT_CREATOR);

        // Create a resource account that will hold the collection, with its signer capability inside
        let (resource_account_signer, capability) = account::create_resource_account(creator, COLLECTION_NAME);
        let controller = CollectionController {
            signer_cap: capability,
            count: 0,
            freeze_mint: false,
        };
        move_to(&resource_account_signer, controller);

        // Create the new collection
        token::create_collection(
            &resource_account_signer,
            string::utf8(COLLECTION_NAME), // Collection Name
            string::utf8(COLLECTION_DESCRIPTION), // Description
            string::utf8(COLLECTION_URI), // Collection URI
            MAX_SUPPLY, // Max Supply
            MUTABILITY_CONFIG, // Mutability Config
        );
    }

    /// Mints a new token, incrementing the counter appropriately
    entry fun mint(minter: &signer) acquires CollectionController {
        let collection_resource_address = account::create_resource_address(&@original_contract, COLLECTION_NAME);
        let controller = borrow_global_mut<CollectionController>(collection_resource_address);
        assert!(!controller.freeze_mint, EMINTING_FROZEN);

        let collection_signer = account::create_signer_with_capability(&controller.signer_cap);

        // Mint token to the minter
        let token_name = string_utils::format1(&b"#{}", controller.count);
        let token_description = string_utils::format2(&b"Just a {} #{}", COLLECTION_NAME, controller.count);
        let uri = string_utils::format1(
            &b"https://nftstorage.link/ipfs/bafybeie2vrobolvih7fijl5e3237gy44gnc4wsmos7jugtsdbrblfkqtwi/{}.jpeg",
            controller.count
        );
        let token_mut_config = create_token_mutability_config(&MUTABILITY_CONFIG);
        let token_data_id = create_tokendata(
            &collection_signer,
            string::utf8(COLLECTION_NAME),
            token_name,
            token_description,
            1,
            uri,
            @original_contract, // Royalty payout address
            100, // Royalty denominator
            0, // Royalty numerator
            token_mut_config,
            vector[], // Property keys
            vector[], // Property values
            vector[] // Property types
        );

        // Mint and transfer to minter
        let token = token::mint_token(
            &collection_signer,
            token_data_id,
            1,
        );
        direct_transfer(&collection_signer, minter, token, 1);

        // Ensure the next one has the next number
        controller.count = controller.count + 1;
    }
}
