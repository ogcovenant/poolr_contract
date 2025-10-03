#[test_only]
module poolr::poolr_test;

use poolr::poolr;
use sui::test_scenario as ts;
use sui::clock;
use sui::table;

const INITIATOR: address = @0xA;
const ALICE: address = @0xB;
const BOB: address = @0xC;

#[test]
fun create_pool_public_and_join() {

  let mut scenario = ts::begin(INITIATOR);

  // Create a pool with the INITIATOR address
  {
    let ctx = ts::ctx(&mut scenario);
    let test_clock = clock::create_for_testing(ctx);

    poolr::create_pool(
       ctx, 
      b"Test Pool".to_string(), 
      b"Just a test pool".to_string(), 
      BOB,
      200,
      70,
      option::some(20),
      60,
      b"PUBLIC".to_string(),
      &test_clock
    );

    test_clock.destroy_for_testing()
  };

  //Join created pool with ALICE address
  ts::next_tx(&mut scenario, ALICE);
  {
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);
    let ctx = ts::ctx(&mut scenario);

    poolr::join_pool(
      ctx,
      &mut pool
    );

    ts::return_shared(pool);
  };

  //Perform tests using BOB addrss
  ts::next_tx(&mut scenario, BOB);
  {
    let pool = ts::take_shared<poolr::Pool>(&scenario);
    let pool_contributors = poolr::get_pool_contributors(&pool);

    assert!(table::contains(pool_contributors, INITIATOR), 0);
    assert!(table::contains(pool_contributors, ALICE), 0);
    assert!(pool.get_pool_status() == poolr::get_pool_status_type(b"OPEN".to_string()), 1);
    assert!(pool.get_pool_deadline() > pool.get_pool_creation(), 2);

    ts::return_shared(pool);
  };
  
  ts::end(scenario);
}