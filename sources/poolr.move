module poolr::poolr;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::table::{Self, Table};
use usdc::usdc::USDC;

const EZeroTargetAmount: u64 = 500;
const EInvalidThreshold: u64 = 501;
const EInvalidStatus: u64 = 502;
const EInvalidVisibility: u64 = 503;
const ECannotJoinPrivatePool: u64 = 504;
const EAddressAlreadyAContributor: u64 = 505;
const EAddressNotAContributor: u64 = 506;
const EInvalidContributionAmount: u64 = 507;
const ETargetAmountReached: u64 = 509;
const EPoolDeadlineReached: u64 = 510;
const ECannotAddAddressToPrivatePool: u64 = 511;
const EZeroDeadlineCount: u64 = 512;
const EAddressAlreadyContributed: u64 = 513;

public enum THRESHOLD_TYPE has store {
    COUNT,
    PERCENTAGE,
}

public enum POOL_STATUS has drop, store {
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
    contributed_amount: u64,
    visibility: POOL_VISIBILITY,
    contributors: Table<address, u64>,
    threshold_type: THRESHOLD_TYPE,
    threshold_contribution: Option<u64>,
    threshold_value: u64,
    voters: Table<address, bool>,
    status: POOL_STATUS,
    creation_timestamp: u64,
    deadline_timestamp: u64,
    pool_escrow: PoolEscrow,
}

public struct PoolInitiatorCap has key {
    id: UID,
    pool_id: ID,
}

public struct PoolCreatedEvent has copy, drop {
    pool_id: ID,
    initiator: address,
}

public struct ContributorAddedToPoolEvent has copy, drop {
    pool_id: ID,
    user_address: address,
}

public struct ContributorJoinedPoolEvent has copy, drop {
    pool_id: ID,
    user_address: address,
}

public struct ContributionAddedEvent has copy, drop {
    pool_id: ID,
    user_address: address,
    amount: u64,
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
    threshold_value: u64,
    threshold_contribution: Option<u64>,
    deadline: u64,
    visibility: String,
    clock: &Clock,
) {
    assert!(target_amount > 0, EZeroTargetAmount);
    assert!(deadline > 0, EZeroDeadlineCount);

    let mut contributors: Table<address, u64> = table::new(ctx);
    let voters: Table<address, bool> = table::new(ctx);

    table::add(&mut contributors, ctx.sender(), 0);

    let current_time = clock::timestamp_ms(clock);
    let deadline_timestamp = current_time + ( deadline * 24 * 60 * 60 * 1000 );

    let pool_escrow = PoolEscrow {
        id: object::new(ctx),
        value: balance::zero<USDC>(),
    };

    let pool = Pool {
        id: object::new(ctx),
        title,
        description,
        initiator: ctx.sender(),
        contributors,
        recipient,
        target_amount,
        contributed_amount: 0,
        threshold_type: get_pool_threshold_type(threshold_type),
        threshold_value,
        threshold_contribution,
        status: POOL_STATUS::OPEN,
        voters,
        creation_timestamp: current_time,
        deadline_timestamp,
        visibility: get_pool_visibility_type(visibility),
        pool_escrow,
    };

    let poolInitiatorCap = PoolInitiatorCap {
        id: object::new(ctx),
        pool_id: object::id(&pool),
    };

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
    assert!(&pool.visibility == POOL_VISIBILITY::PRIVATE, ECannotAddAddressToPrivatePool);
    assert!(!table::contains(&pool.contributors, user_address), EAddressAlreadyAContributor);
    table::add(&mut pool.contributors, user_address, 0);

    event::emit(ContributorAddedToPoolEvent {
        pool_id: object::id(pool),
        user_address,
    })
}

public fun join_pool(ctx: &mut TxContext, pool: &mut Pool) {
    assert!(&pool.visibility == POOL_VISIBILITY::PUBLIC, ECannotJoinPrivatePool);
    assert!(!table::contains(&pool.contributors, ctx.sender()), EAddressAlreadyAContributor);

    table::add(&mut pool.contributors, ctx.sender(), 0);

    event::emit(ContributorJoinedPoolEvent {
        pool_id: object::id(pool),
        user_address: ctx.sender(),
    })
}

public fun contribute_to_pool(
    contribution: Coin<USDC>,
    pool: &mut Pool,
    ctx: &mut TxContext,
    clock: &Clock,
) {
    let contributors = &pool.contributors;
    let user_contribution = coin::value(&contribution);
    let current_timestamp = clock::timestamp_ms(clock);

    assert!(current_timestamp < pool.deadline_timestamp, EPoolDeadlineReached);
    assert!(table::contains(contributors, ctx.sender()), EAddressNotAContributor);
    assert!(
        user_contribution >= *option::borrow(&pool.threshold_contribution),
        EInvalidContributionAmount,
    );
    assert!(pool.contributed_amount < pool.target_amount, ETargetAmountReached);

    let existing_contribution = table::borrow_mut(&mut pool.contributors, ctx.sender());
    assert!(existing_contribution == 0, EAddressAlreadyContributed);

    let pool_escrow = &mut pool.pool_escrow;
    let user_contribution_balance = coin::into_balance(contribution);
    balance::join(&mut pool_escrow.value, user_contribution_balance);
    *existing_contribution = *existing_contribution + user_contribution;

    pool.contributed_amount = pool.contributed_amount + user_contribution;

    if (pool.contributed_amount >= pool.target_amount) {
        pool.status = POOL_STATUS::FUNDED;
    };
    event::emit(ContributionAddedEvent {
        pool_id: object::id(pool),
        user_address: ctx.sender(),
        amount: user_contribution,
    })
}

public fun get_contributed_amount(pool: &Pool): u64 {
    pool.contributed_amount
}

public fun request_pool_release() {}

public fun vote() {}

public fun release_pool_funds() {}

public fun cancel_and_refund_pool() {}

public fun reuse_funds() {}

public fun get_pool() {}

public fun list_pool_contributors() {}

public fun get_contribution_of() {}
