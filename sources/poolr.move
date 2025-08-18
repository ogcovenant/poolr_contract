module poolr::poolr;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::dynamic_object_field as dof;
use sui::event;
use sui::table::{Self, Table};
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

public enum POOL_VISIBILITY has store {
    PRIVATE,
    PUBLIC,
}

public struct PoolEscrowKey has copy, drop, store {}

public struct PoolEscrow has key, store {
    id: UID,
    value: Balance<USDC>,
}

public struct Pool has key {
    id: UID,
    title: String,
    description: String,
    initiator: address,
    recipient: address,
    target_amount: u64,
    visibility: POOL_VISIBILITY,
    contributors: vector<address>,
    contributions: Table<address, u64>,
    threshold_contribution: Option<u64>,
    voters: Table<address, bool>,
    threshold_type: THRESHOLD_TYPE,
    threshold_value: u8,
    status: POOL_STATUS,
    deadline_ms: u64,
}

public struct PoolCreatedEvent has copy, drop {
    pool_id: ID,
    initiator: address,
}

public fun create_pool(
    ctx: &mut TxContext,
    title: String,
    description: String,
    recipient: address,
    target_amount: u64,
    threshold_type: THRESHOLD_TYPE,
    threshold_value: u8,
    threshold_contribution: Option<u64>,
    deadline_ms: u64,
    visibility: POOL_VISIBILITY,
) {
    let mut contributors = vector::empty<address>();
    vector::push_back(&mut contributors, ctx.sender());

    let contributions: Table<address, u64> = table::new(ctx);
    let voters: Table<address, bool> = table::new(ctx);

    let mut pool = Pool {
        id: object::new(ctx),
        title,
        description,
        initiator: ctx.sender(),
        contributors,
        recipient,
        target_amount,
        threshold_type,
        threshold_value,
        threshold_contribution,
        status: POOL_STATUS::OPEN,
        voters,
        contributions,
        deadline_ms,
        visibility,
    };

    let pool_escrow = PoolEscrow {
        id: object::new(ctx),
        value: balance::zero<USDC>(),
    };

    dof::add(&mut pool.id, PoolEscrowKey {}, pool_escrow);

    event::emit(PoolCreatedEvent {
        pool_id: object::id(&pool),
        initiator: ctx.sender(),
    });

    transfer::share_object(pool)
}

public fun add_contributor_to_pool(
    &mut Pool,
    user_address: address
) {
    
}

public fun join_pool() {}

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
