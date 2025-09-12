#[test_only]
module poolr::poolr_test;

use poolr::poolr::{create_pool, Pool, add_contributor_to_pool, PoolInitiatorCap, join_pool};
use sui::clock;
use sui::table;
use sui::test_scenario as ts;

const BOB: address = @0xA;
const A11C3: address = @0xB;

#[test]
fun test_pool_creation() {
    //initialise test scenario
    let mut scenario = ts::begin(BOB);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    create_pool(
        ts::ctx(&mut scenario),
        b"Test Pool".to_string(),
        b"Just Testing Pool Creation".to_string(),
        A11C3,
        200,
        b"PERCENTAGE".to_string(),
        65,
        option::some(0),
        30,
        b"PUBLIC".to_string(),
        &clock,
    );

    ts::next_tx(&mut scenario, BOB);
    {
        let pool = ts::take_shared<Pool>(&scenario);

        assert!(pool.get_pool_initiator() == BOB, 1);

        ts::return_shared<Pool>(pool);
    };

    clock.destroy_for_testing();
    ts::end(scenario);
}

#[test]
fun test_contributor_addition() {
    let mut scenario = ts::begin(BOB);
    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    create_pool(
        ts::ctx(&mut scenario),
        b"Test Pool".to_string(),
        b"Just Testing Pool Creation".to_string(),
        A11C3,
        200,
        b"PERCENTAGE".to_string(),
        65,
        option::some(0),
        30,
        b"PRIVATE".to_string(),
        &clock,
    );

    ts::next_tx(&mut scenario, BOB);
    {
        let mut pool = ts::take_shared<Pool>(&scenario);
        let initiator_cap = ts::take_from_sender<PoolInitiatorCap>(&scenario);

        add_contributor_to_pool(&mut pool, A11C3, &initiator_cap);

        ts::return_shared<Pool>(pool);
        ts::return_to_sender(&scenario, initiator_cap);
    };
    ts::next_tx(&mut scenario, BOB);
    {
        let pool = ts::take_shared<Pool>(&scenario);
        let contributors = pool.get_pool_contributors();

        assert!(table::contains(contributors, A11C3), 2);
        ts::return_shared<Pool>(pool);
    };

    clock.destroy_for_testing();
    ts::end(scenario);
}

#[test]
fun test_join_pool() {
    let mut scenario = ts::begin(BOB);

    let clock = clock::create_for_testing(ts::ctx(&mut scenario));

    create_pool(
        ts::ctx(&mut scenario),
        b"Test Pool".to_string(),
        b"Just Testing Pool Creation".to_string(),
        A11C3,
        200,
        b"PERCENTAGE".to_string(),
        65,
        option::some(0),
        30,
        b"PUBLIC".to_string(),
        &clock,
    );

    ts::next_tx(&mut scenario, A11C3);
    {
        let mut pool = ts::take_shared<Pool>(&scenario);

        join_pool(ts::ctx(&mut scenario), &mut pool);

        ts::return_shared<Pool>(pool);
    };
    ts::next_tx(&mut scenario, BOB);
    {
        let pool = ts::take_shared<Pool>(&scenario);
        let contributors = pool.get_pool_contributors();

        assert!(table::contains(contributors, A11C3), 2);
        ts::return_shared<Pool>(pool);
    };
    clock.destroy_for_testing();
    ts::end(scenario);
}
