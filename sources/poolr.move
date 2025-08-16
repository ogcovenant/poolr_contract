module poolr::poolr;

use std::string::String;
use sui::coin::Coin;
use sui::table::Table;
use usdc::usdc::USDC;

public enum THRESHOLD_TYPE has store {
    COUNT,
    PERCENTAGE,
}

public enum POOL_STATUS has store {
    OPEN,
    FUNDED,
    VOTING,
    EXECUTED,
    REFUNDED,
    REUSED,
}

public struct PoolEscrow has key, store {
    id: UID,
    value: Coin<USDC>,
}

public struct Pool has key {
    id: UID,
    title: String,
    description: String,
    initiator: address,
    recipient: address,
    target_amount: u64,
    contributions: Table<address, u64>,
    threshold_contribution: Option<u64>,
    voters: Table<address, bool>,
    threshold_type: THRESHOLD_TYPE,
    threshold_value: u8,
    status: POOL_STATUS,
}

public entry fun create_pool() {}

public fun add_contributor_to_pool() {}

public fun remove_contributor_from_pool() {}

public fun convert_contributor_to_adomin() {}

public fun contribute_to_pool() {}

public fun request_pool_release() {}

public fun vote() {}

public fun release_pool_funds() {}

public fun cancel_and_refund_pool() {}

public fun reuse_funds() {}

public fun get_pool() {}

public fun list_pool_contributors() {}

public fun get_contribution_of() {}
