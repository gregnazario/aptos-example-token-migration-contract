module new_contract::new_nft {

    use std::signer;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::aptos_account;
    use aptos_framework::object;
    use aptos_framework::object::{ExtendRef};
    use aptos_token::token;
    use aptos_token::token::create_token_id;
    use aptos_token_objects::aptos_token;

    const OLD_COLLECTION_NAME: vector<u8> = b"Sleepy Crows";
    const COLLECTION_NAME: vector<u8> = b"Rising Phoenix";
    const OBJECT_SEED: vector<u8> = b"SomeSeedNew";

    /// Not authorized, caller is not the creator of the contract
    const ENOT_CREATOR: u64 = 1;
    /// Old token doesn't exist
    const EOLD_TOKEN_DOESNT_EXIST: u64 = 2;
    /// Not authorized, minting is frozen
    const EMINTING_FROZEN: u64 = 3;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct CollectionController has key {
        extend_ref: ExtendRef,
        freeze_mint: bool,
    }

    entry fun freeze_mint(creator: &signer, freeze: bool) acquires CollectionController {
        // Simple access control
        assert!(signer::address_of(creator) == @new_contract, ENOT_CREATOR);

        let controller_object_address = object::create_object_address(&@new_contract, OBJECT_SEED);
        let controller = borrow_global_mut<CollectionController>(controller_object_address);
        controller.freeze_mint = freeze;
    }

    entry fun init(creator: &signer) {
        // Simple access control
        assert!(signer::address_of(creator) == @new_contract, ENOT_CREATOR);

        // Create an object that will hold the collection
        let constructor_ref = object::create_named_object(creator, OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let collection_signer = object::generate_signer(&constructor_ref);

        let controller = CollectionController {
            extend_ref,
            freeze_mint: false,
        };
        move_to(&collection_signer, controller);
        // Make the object also an account so we can send V1 tokens to it
        aptos_account::create_account(signer::address_of(&collection_signer));

        let original_creator_address = @0xcc7fa91ef4b4ad78c7ee32eae175443598f48ae66d0e5bd2ecea08cf88fd9042;
        let old_collection_name = string::utf8(OLD_COLLECTION_NAME);
        let max_supply = token::get_collection_maximum(original_creator_address, old_collection_name);
        let description = token::get_collection_description(original_creator_address, old_collection_name);
        let uri = token::get_collection_uri(original_creator_address, old_collection_name);

        // Create the new collection
        aptos_token::create_collection(
            &collection_signer,
            description,
            max_supply,
            string::utf8(COLLECTION_NAME), // Collection Name, this could be taken from the old one
            uri,
            // We make everything mutable for flexibility, but this could be taken from the previous collection
            true, // Collection description mutable
            true, // Collection Royalty mutable
            true, // Collection URI mutable
            true, // Token description mutable
            true, // Token name mutable
            true, // Token properties mutable
            true, // Token image URI mutable
            true, // Tokens burnable by creator
            true, // Tokens freezable by creator
            0, // Royalty numerator
            100, // Royalty denominator
        )
    }

    entry fun burn_and_mint(minter: &signer, token_name: string::String) acquires CollectionController {
        // Check if it exists
        let original_creator_address = @0xcc7fa91ef4b4ad78c7ee32eae175443598f48ae66d0e5bd2ecea08cf88fd9042;
        let old_collection_name = string::utf8(OLD_COLLECTION_NAME);
        assert!(
            token::check_tokendata_exists(original_creator_address, old_collection_name, token_name),
            EOLD_TOKEN_DOESNT_EXIST
        );

        let old_token_data_id = token::create_token_data_id(original_creator_address, old_collection_name, token_name);
        let old_token_version = token::get_tokendata_largest_property_version(
            original_creator_address,
            old_token_data_id
        );
        let description = string_utils::format2(&b"Rising from the ashes {} {}", COLLECTION_NAME, token_name);
        let uri = token::get_tokendata_uri(original_creator_address, old_token_data_id);

        // We will check ownership when we try to transfer to the new object
        let creator_address = get_creator_address();
        let controller = borrow_global<CollectionController>(creator_address);
        // Ensure freezing is enabled
        assert!(!controller.freeze_mint, EMINTING_FROZEN);

        let collection_signer = object::generate_signer_for_extending(&controller.extend_ref);

        // Create the new token
        let collection_name = string::utf8(COLLECTION_NAME);
        let new_token = aptos_token::mint_token_object(
            &collection_signer,
            collection_name,
            description,
            token_name,
            uri,
            vector[], // Property keys
            vector[], // Property types
            vector [], // Property values
        );

        // Transfer the old token to be owned by the collection
        let old_token_id = create_token_id(old_token_data_id, old_token_version);
        token::direct_transfer(minter, &collection_signer, old_token_id, 1);

        // Transfer the new token to be owned by the user
        object::transfer(&collection_signer, new_token, signer::address_of(minter));
    }

    inline fun get_creator_address(): address {
        //@0x6c59c6a2c1145e867b5d136924d47b5576ad630e89d51d86bed13553800c0ed8
        object::create_object_address(&@new_contract, OBJECT_SEED)
    }
}
