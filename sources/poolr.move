module poolr::poolr;

use std::string::String;
use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::table::{Self, Table};
use usdc::usdc::USDC;

const TOTAL_VOTING_POWER: u64 = 1_000_000_000;

const EZeroTargetAmount: u64 = 500;
const EInvalidStatus: u64 = 502;
const EInvalidVisibility: u64 = 503;
const ECannotJoinPrivatePool: u64 = 504;
const EAddressAlreadyAContributor: u64 = 505;
const EAddressNotAContributor: u64 = 506;
const EInvalidContributionAmount: u64 = 507;
const ETargetAmountReached: u64 = 509;
const EPoolDeadlineReached: u64 = 510;
const ECannotAddAddressToPublicPool: u64 = 511;
const EZeroDeadlineCount: u64 = 512;
const EAddressNotPoolInitiator: u64 = 514;
const ECannotContributeToClosedPool: u64 = 515;
const EContributedAmountIsLowForThisAction: u64 = 516;
const ECannotAddContributorToClosedPool: u64 = 517;
const ECannotInitializeFundingOnClosedPool: u64 = 518;
const ECannotJoinClosedPool: u64 = 519;
const EPoolHasNotBeenInitializedForVoting: u64 = 520;
const EInvalidVoteChoice: u64 = 521;
const EAddressNotAVoter: u64 = 522;
const EVotingRequirementNotMet: u64 = 523;
const ECannotReleaseFundsOnOpenPool: u64 = 524;
const EPoolNotRejected: u64 = 525;

public enum POOL_STATUS has drop, store, copy {
    OPEN,
    FUNDING,
    FUNDED,
    VOTING,
    RELEASED,
    REJECTED,
    REFUNDING,
    REFUNDED
}

public enum POOL_VISIBILITY has drop, store, copy {
    PRIVATE,
    PUBLIC,
}

public enum VOTE_CHOICE has copy, drop, store {
    YES,
    NO
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
    threshold_contribution: Option<u64>,
    voting_threshold: u64,
    voters: Table<address, u64>,
    yes_votes: u64,
    no_votes: u64,
    total_votes: u64,
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

public struct PoolFundingInitialisedEvent has copy, drop {
    pool_id: ID
}

public struct PoolReleaseRequestEvent has copy, drop {
    pool_id: ID
}

public struct PoolVotedEvent has copy, drop {
    pool_id: ID,
    voter: address,
    choice: String
}

public struct PoolReleasedEvent has copy, drop {
    pool_id: ID,
    receipient: address
}

public struct PoolRefundClaimed has copy, drop {
    pool_id: ID,
    receipient: address,
    amount: u64
}

public fun get_pool_status_type(status: String): POOL_STATUS {
    if (
    status != b"OPEN".to_string() &&
    status != b"FUNDING".to_string() &&
    status != b"FUNDED".to_string() &&
    status != b"VOTING".to_string() &&
    status != b"RELEASED".to_string() &&
    status != b"REJECTED".to_string() &&
    status != b"REFUNDING".to_string() &&
    status != b"REFUNDED".to_string()
) {
    abort EInvalidStatus
};


    if (status == b"OPEN".to_string()) {
        POOL_STATUS::OPEN
    } else if (status == b"FUNDING".to_string()) {
        POOL_STATUS::FUNDING
    }else if (status == b"FUNDED".to_string()) {
        POOL_STATUS::FUNDED
    } else if (status == b"VOTING".to_string()) {
        POOL_STATUS::VOTING
    }else if (status == b"RELEASED".to_string()) {
        POOL_STATUS::RELEASED
    }else if (status == b"REJECTED".to_string()) {
        POOL_STATUS::REJECTED
    }else if (status == b"REFUNDED".to_string()) {
        POOL_STATUS::REFUNDED
    } else {
        POOL_STATUS::REFUNDING
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
    voting_threshold: u64,
    threshold_contribution: Option<u64>,
    deadline: u64,
    visibility: String,
    clock: &Clock,
) {
    assert!(target_amount > 0, EZeroTargetAmount);
    assert!(deadline > 0, EZeroDeadlineCount);

    let mut contributors: Table<address, u64> = table::new(ctx);
    let mut voters: Table<address, u64> = table::new(ctx);

    table::add(&mut contributors, ctx.sender(), 0);
    table::add(&mut voters, ctx.sender(), 0);

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
        threshold_contribution,
        voting_threshold,
        total_votes: 0,
        status: POOL_STATUS::OPEN,
        voters,
        yes_votes: 0,
        no_votes: 0,
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

public entry fun add_contributor_to_pool(
    pool: &mut Pool,
    user_address: address,
    pool_initiator_cap: &PoolInitiatorCap,
) {
    assert!(pool_initiator_cap.pool_id == object::id(pool), EAddressNotPoolInitiator);
    assert!(pool.visibility == POOL_VISIBILITY::PRIVATE, ECannotAddAddressToPublicPool);
    assert!(pool.status == POOL_STATUS::OPEN, ECannotAddContributorToClosedPool);
    assert!(!table::contains(&pool.contributors, user_address), EAddressAlreadyAContributor);

    table::add(&mut pool.contributors, user_address, 0);
    table::add(&mut pool.voters, user_address, 0);
    

    event::emit(ContributorAddedToPoolEvent {
        pool_id: object::id(pool),
        user_address,
    })
}

public fun join_pool(ctx: &mut TxContext, pool: &mut Pool) {
    assert!(pool.visibility == POOL_VISIBILITY::PUBLIC, ECannotJoinPrivatePool);
    assert!(pool.status == POOL_STATUS::OPEN, ECannotJoinClosedPool);
    assert!(!table::contains(&pool.contributors, ctx.sender()), EAddressAlreadyAContributor);

    table::add(&mut pool.contributors, ctx.sender(), 0);
     table::add(&mut pool.voters, ctx.sender(), 0);

    event::emit(ContributorJoinedPoolEvent {
        pool_id: object::id(pool),
        user_address: ctx.sender(),
    })
}

public entry fun initialize_pool_funding(pool: &mut Pool, pool_initiator_cap: &PoolInitiatorCap,) {
    assert!(pool_initiator_cap.pool_id == object::id(pool), EAddressNotPoolInitiator);
    assert!(pool.status == POOL_STATUS::OPEN, ECannotInitializeFundingOnClosedPool);

    pool.status = POOL_STATUS::FUNDING;

    event::emit(PoolFundingInitialisedEvent {
        pool_id: object::id(pool)
    })
}

public fun contribute_to_pool(
    contribution: Coin<USDC>,
    pool: &mut Pool,
    ctx: &mut TxContext,
    clock: &Clock,
) {
    let contributors = &mut pool.contributors;
    let user_contribution = coin::value(&contribution);
    let current_timestamp = clock::timestamp_ms(clock);
    let voters = &mut pool.voters;
    

    assert!(pool.status == POOL_STATUS::FUNDING, ECannotContributeToClosedPool);
    assert!(current_timestamp < pool.deadline_timestamp, EPoolDeadlineReached);
    assert!(table::contains(contributors, ctx.sender()), EAddressNotAContributor);
    assert!(table::contains(voters, ctx.sender()), EAddressNotAVoter);
    if (option::is_some(&pool.threshold_contribution)) {
        assert!(
            user_contribution >= *option::borrow(&pool.threshold_contribution),
            EInvalidContributionAmount,
        );
    };
    assert!(
        pool.contributed_amount + user_contribution <= pool.target_amount,
        ETargetAmountReached,
    );

    let contributor_current_voting_power = table::borrow_mut(voters, ctx.sender());

    let existing_contribution = table::borrow_mut(contributors, ctx.sender());

    let pool_escrow = &mut pool.pool_escrow;
    let user_contribution_balance = coin::into_balance(contribution);
    balance::join(&mut pool_escrow.value, user_contribution_balance);
    *existing_contribution = *existing_contribution + user_contribution;

    pool.contributed_amount = pool.contributed_amount + user_contribution;
   
    let voting_power_to_be_assigned = ( (user_contribution as u128) * (TOTAL_VOTING_POWER as u128) ) / (pool.target_amount as u128);

    *contributor_current_voting_power = *contributor_current_voting_power + (voting_power_to_be_assigned as u64);

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

public entry fun request_pool_release(pool: &mut Pool, pool_initiator_cap: &PoolInitiatorCap) {
    assert!(pool_initiator_cap.pool_id == object::id(pool), EAddressNotPoolInitiator);
    assert!(pool.status == POOL_STATUS::FUNDED, EContributedAmountIsLowForThisAction);

    pool.status = POOL_STATUS::VOTING;

    event::emit(PoolReleaseRequestEvent {
        pool_id: object::id(pool)
    })
}

public fun get_vote_choice (choice: String): VOTE_CHOICE {
    if(choice != b"YES".to_string() && choice != b"NO".to_string()) {
        abort EInvalidVoteChoice
    };

    if(choice == b"YES".to_string()){ 
        VOTE_CHOICE::YES
    }else {
        VOTE_CHOICE::NO
    }
}

public entry fun vote(pool: &mut Pool, choice: String, ctx: &TxContext) {
    let voters = &mut pool.voters;

    assert!(pool.status == POOL_STATUS::VOTING, EPoolHasNotBeenInitializedForVoting);
    assert!(table::contains(voters, ctx.sender()), EAddressNotAContributor);

    let user_voting_power = table::borrow_mut(voters, ctx.sender());
    let user_vote_choice = get_vote_choice(choice);

    if(user_vote_choice == VOTE_CHOICE::YES){
        pool.yes_votes = pool.yes_votes + *user_voting_power;
        pool.total_votes = pool.total_votes + *user_voting_power;

        *user_voting_power = 0;
    }else {
        pool.no_votes = pool.no_votes + *user_voting_power;
        pool.total_votes = pool.total_votes + *user_voting_power;

        *user_voting_power = 0;
    };

    event::emit(PoolVotedEvent {
        pool_id: object::id(pool),
        voter: ctx.sender(),
        choice
    })
}

public entry fun release_pool_funds(pool: &mut Pool, pool_initiator_cap: &PoolInitiatorCap, ctx: &mut TxContext) {
    assert!(pool_initiator_cap.pool_id == object::id(pool), EAddressNotPoolInitiator);
    assert!(pool.status == POOL_STATUS::VOTING, ECannotReleaseFundsOnOpenPool);

    let voting_threshold = ((pool.voting_threshold as u128) * (TOTAL_VOTING_POWER as u128)) / 100;
    assert!(pool.total_votes >= (voting_threshold as u64), EVotingRequirementNotMet);

    if(pool.yes_votes > pool.no_votes) {
        let amount_to_release = balance::value(&pool.pool_escrow.value);

        let funds_to_transfer_balance = balance::split(&mut pool.pool_escrow.value, amount_to_release);
        let funds_to_transfer_coin = coin::from_balance(funds_to_transfer_balance, ctx);

        transfer::public_transfer(funds_to_transfer_coin, pool.recipient);

        pool.status = POOL_STATUS::RELEASED;

        event::emit(PoolReleasedEvent {
            pool_id: object::id(pool),
            receipient: pool.recipient
        })
    }else {
        pool.status = POOL_STATUS::REJECTED;
    }
}

public entry fun initialize_pool_refund(pool: &mut Pool, pool_initiator_cap: &PoolInitiatorCap) {
    assert!(pool.status == POOL_STATUS::REJECTED, EPoolNotRejected);
    assert!(pool_initiator_cap.pool_id == object::id(pool));

    pool.status = POOL_STATUS::REFUNDING
}

#[allow(lint(self_transfer))]
public entry fun claim_pool_refund(pool: &mut Pool, ctx: &mut TxContext) {
    let contributors = &mut pool.contributors;

    assert!(table::contains(contributors, ctx.sender()), EAddressNotAContributor);

    let contribution = table::borrow_mut(contributors, ctx.sender());
    let contribution_amount = *contribution;

    assert!(*contribution > 0, EInvalidContributionAmount);

    *contribution = 0;

    let amount_to_refund_balance = balance::split(&mut pool.pool_escrow.value, contribution_amount); 
    let amount_to_refund_coin = coin::from_balance(amount_to_refund_balance, ctx);

    transfer::public_transfer(amount_to_refund_coin, ctx.sender());

    event::emit(PoolRefundClaimed {
        pool_id: object::id(pool),
        receipient: ctx.sender(),
        amount: *contribution
    });

    let remaining_funds = balance::value(&pool.pool_escrow.value);

    if(remaining_funds == 0) {
        pool.status = POOL_STATUS::REFUNDED
    }
}