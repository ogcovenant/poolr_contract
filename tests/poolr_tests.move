#[test_only]
module poolr::poolr_test;

use poolr::poolr;
use sui::test_scenario as ts;
use sui::clock;

const INITIATOR: address = @0xA;
const ALICE: address = @0xB;
const BOB: address = @0xC;

#[test]
fun create_pool_public_and_join() {

  let mut scenario = ts::begin(INITIATOR);

  // Create a pool with the INITIATOR address
  {
    let mut ctx = ts::ctx(&mut scenario);
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
    )
  };

  //Join created pool with ALICE address
  ts::next_tx(&mut scenario, ALICE);
  {
    let mut ctx = ts::ctx(&mut scenario);
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);

    poolr::join_pool(
      ctx,
      pool
    )
  }


}