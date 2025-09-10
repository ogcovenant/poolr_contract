module poolr::poolr;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::dynamic_object_field as dof;
use sui::event;
use sui::table::{Self, Table};
use usdc::usdc::USDC;

const EInvalidThreshold: u64 = 501;
const EInvalidStatus: u64 = 502;
const EInvalidVisibility: u64 = 503;
const ECannotJoinPrivatePool: u64 = 504;

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

public enum POOL_VISIBILITY has drop, store {
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
    contributors: Table<address, u64>,
    threshold_contribution: Option<u64>,
    voters: Table<address, bool>,
    threshold_type: THRESHOLD_TYPE,
    threshold_value: u8,
    status: POOL_STATUS,
    deadline_ms: u64,
}

public struct PoolInitiatorCap has key {
    id: UID,
}

public struct PoolCreatedEvent has copy, drop {
    pool_id: ID,
    initiator: address,
}

public fun get_pool_threshold_type(threshold: String): THRESHOLD_TYPE {
    if (threshold != b"COUNT".to_string() && threshold != b"PERCENTAGE".to_string()) {
        abort EInvalidThreshold
    };

    if (threshold == b"COUNT".to_string()) {
        THRESHOLD_TYPE::COUNT
    } else {
        THRESHOLD_TYPE::PERCENTAGE
    }
}

public fun get_pool_status_type(status: String): POOL_STATUS {
    if (
        status != b"OPEN".to_string() && status != b"FUNDED".to_string() && status != b"VOTING".to_string() && status != b"EXECUTED".to_string() && status != b"REFUNDED".to_string() && status != b"REUSED".to_string()
    ) {
        abort EInvalidStatus
    };

    if (status == b"OPEN".to_string()) {
        POOL_STATUS::OPEN
    } else if (status == b"FUNDED".to_string()) {
        POOL_STATUS::FUNDED
    } else if (status == b"VOTING".to_string()) {
        POOL_STATUS::VOTING
    } else if (status == b"EXECUTED".to_string()) {
        POOL_STATUS::EXECUTED
    } else if (status == b"REFUNDED".to_string()) {
        POOL_STATUS::REFUNDED
    } else {
        POOL_STATUS::REUSED
    }
}

public fun get_pool_visibility_type(visibility: String): POOL_VISIBILITY {
    if (visibility != b"PRIVATE".to_string() && visibility != b"PUBLIC".to_string()) {
        abort EInvalidVisibility
    };
    if (visibility == b"PRIVATE".to_string()) {
        POOL_VISIBILITY::PRIVATE
    } else {
        POOL_VISIBILITY::PUBLIC
    }
}

public fun create_pool(
    ctx: &mut TxContext,
    title: String,
    description: String,
    recipient: address,
    target_amount: u64,
    threshold_type: String,
    threshold_value: u8,
    threshold_contribution: Option<u64>,
    deadline_ms: u64,
    visibility: String,
) {
    let mut contributors = vector::empty<address>();
    vector::push_back(&mut contributors, ctx.sender());

    let contributors: Table<address, u64> = table::new(ctx);
    let voters: Table<address, bool> = table::new(ctx);

    let mut pool = Pool {
        id: object::new(ctx),
        title,
        description,
        initiator: ctx.sender(),
        contributors,
        recipient,
        target_amount,
        threshold_type: get_pool_threshold_type(threshold_type),
        threshold_value,
        threshold_contribution,
        status: POOL_STATUS::OPEN,
        voters,
        deadline_ms,
        visibility: get_pool_visibility_type(visibility),
    };

    let poolInitiatorCap = PoolInitiatorCap {
        id: object::new(ctx),
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

    transfer::share_object(pool);
    transfer::transfer(poolInitiatorCap, ctx.sender())
}

public fun get_pool_initiator(pool: &Pool): address {
    pool.initiator
}

public fun get_pool_contributors(pool: &Pool): &Table<address, u64> {
    &pool.contributors
}

public fun add_contributor_to_pool(pool: &mut Pool, user_address: address, _: &PoolInitiatorCap) {
    if (!table::contains(&pool.contributors, user_address)) {
        table::add(&mut pool.contributors, user_address, 0);
    }
}

public fun join_pool(ctx: &mut TxContext, pool: &mut Pool) {
    assert!(&pool.visibility == POOL_VISIBILITY::PUBLIC, ECannotJoinPrivatePool);

    if (!table::contains(&pool.contributors, ctx.sender())) {
        table::add(&mut pool.contributors, ctx.sender(), 0);
    }
}

public fun remove_contributor_from_pool() {}

public fun convert_contributor_to_admin() {}

public fun contribute_to_pool() {}

public fun request_pool_release() {}

public fun vote() {}

public fun release_pool_funds() {}

public fun cancel_and_refund_pool() {}

public fun reuse_funds() {}

public fun get_pool() {}

public fun list_pool_contributors() {}

public fun get_contribution_of() {}
