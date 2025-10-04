#[test_only]
module poolr::poolr_test;

use poolr::poolr;
use sui::test_scenario as ts;
use sui::clock;
use sui::table;
use sui::coin;
use usdc::usdc::USDC;
use sui::balance;

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

#[test]
fun initialize_funding_and_contribute_to_funded() {
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
      b"PRIVATE".to_string(),
      &test_clock
    );

    test_clock.destroy_for_testing()
  };

    //Add ALICE and BOB as contributors to the pool
  ts::next_tx(&mut scenario, INITIATOR);
  {
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);
    let pool_initiator_cap = ts::take_from_sender<poolr::PoolInitiatorCap>(&scenario);

    poolr::add_contributor_to_pool(&mut pool, BOB, &pool_initiator_cap);
    poolr::add_contributor_to_pool(&mut pool, ALICE, &pool_initiator_cap);

    ts::return_shared(pool);
    ts::return_to_sender(&scenario, pool_initiator_cap);
  };

  //initialize pool funding
  ts::next_tx(&mut scenario, INITIATOR);
  {
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);
    let pool_initiator_cap = ts::take_from_sender<poolr::PoolInitiatorCap>(&scenario);

    poolr::initialize_pool_funding(&mut pool, &pool_initiator_cap);

    ts::return_shared(pool);
    ts::return_to_sender(&scenario, pool_initiator_cap);
  };

  //Create coin object and transfer to ALICE and BOB
  ts::next_tx(&mut scenario, INITIATOR);
  {
    let ctx = ts::ctx(&mut scenario);
    let mut test_usdc_coin: coin::Coin<USDC> = coin::mint_for_testing<USDC>(200, ctx);

    let alice_coin = coin::split(&mut test_usdc_coin, 100, ctx);
    
    transfer::public_transfer(alice_coin, ALICE);
    transfer::public_transfer(test_usdc_coin, BOB)
  };

  //Contribute too pool using BOB
  ts::next_tx(&mut scenario, BOB);
  {
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);
    let bob_contribution = ts::take_from_sender<coin::Coin<USDC>>(&scenario);
    let ctx = ts::ctx(&mut scenario);
    let test_clock = clock::create_for_testing(ctx);

    poolr::contribute_to_pool(bob_contribution, &mut pool, ctx, &test_clock);

    ts::return_shared(pool);
    test_clock.destroy_for_testing();
  };

  //Contribute to the pool using ALICE
  ts::next_tx(&mut scenario, ALICE);
  {
    let mut pool = ts::take_shared<poolr::Pool>(&scenario);
    let alice_contribution = ts::take_from_sender<coin::Coin<USDC>>(&scenario);
    let ctx = ts::ctx(&mut scenario);
    let test_clock = clock::create_for_testing(ctx);

    poolr::contribute_to_pool(alice_contribution, &mut pool, ctx, &test_clock);

    ts::return_shared(pool);
    test_clock.destroy_for_testing();
  };

  //Perform test using INITIATOR address
  ts::next_tx(&mut scenario, INITIATOR);
  {
    let pool = ts::take_shared<poolr::Pool>(&scenario);

    assert!(pool.get_pool_status() == poolr::get_pool_status_type(b"FUNDED".to_string()), 0);
    assert!(pool.get_contributed_amount() == pool.get_target_amount(), 1);
    assert!(balance::value(pool.get_pool_escrow_value()) == pool.get_target_amount(), 2);
    
    let voters = pool.get_pool_voters();
    
    assert!(*table::borrow(voters, BOB) > 0, 3);
    assert!(*table::borrow(voters, ALICE) > 0, 3);

    assert!(pool.get_yes_votes() == 0, 4);
    assert!(pool.get_no_votes() == 0, 4);
    assert!(pool.get_total_votes() == 0, 4);

    ts::return_shared(pool)
  };

  ts::end(scenario);
}