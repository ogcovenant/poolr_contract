#[test_only]
module poolr::poolr_test;

use poolr::poolr::{
    create_pool,
    get_pool_threshold_type,
    get_pool_visibility_type,
    Pool,
    add_contributor_to_pool,
    PoolInitiatorCap
};
use sui::table;
use sui::test_scenario as ts;

const BOB: address = @0xA;
const A11C3: address = @0xB;

#[test]
fun test_pool_creation() {
    //initialise test scenario
    let mut scenario = ts::begin(BOB);

    //Create pool
    create_pool(
        ts::ctx(&mut scenario),
        b"Test Pool".to_string(),
        b"Just Testing Pool Creation".to_string(),
        A11C3,
        200,
        get_pool_threshold_type(b"PERCENTAGE".to_string()),
        65,
        option::some(0),
        30,
        get_pool_visibility_type(b"PUBLIC".to_string()),
    );

    ts::next_tx(&mut scenario, BOB);
    {
        let pool = ts::take_shared<Pool>(&scenario);

        assert!(pool.get_pool_initiator() == BOB, 1);

        ts::return_shared<Pool>(pool);
    };
    ts::end(scenario);
}

#[test]
#[allow(implicit_const_copy)]
fun test_contributor_addition() {
    let mut scenario = ts::begin(BOB);
    let test_pool;

    create_pool(
        ts::ctx(&mut scenario),
        b"Test Pool".to_string(),
        b"Just Testing Pool Creation".to_string(),
        A11C3,
        200,
        get_pool_threshold_type(b"PERCENTAGE".to_string()),
        65,
        option::some(0),
        30,
        get_pool_visibility_type(b"PUBLIC".to_string()),
    );

    ts::next_tx(&mut scenario, BOB);
    {
        let mut pool = ts::take_shared<Pool>(&scenario);
        let initiator_cap = ts::take_from_sender<PoolInitiatorCap>(&scenario);

        add_contributor_to_pool(&mut pool, A11C3, &initiator_cap);

        test_pool = pool;
        ts::return_to_sender(&scenario, initiator_cap);
    };
    ts::next_tx(&mut scenario, BOB);
    {
        let contributors = test_pool.get_pool_contributors();

        assert!(table::contains(contributors, *&A11C3), 2);
        ts::return_shared<Pool>(test_pool);
    };
    ts::end(scenario);
}
