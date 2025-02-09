use starknet::ContractAddress;
use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use snforge_std::{declare, ContractClassFactory, start_prank, stop_prank};

#[starknet::interface]
trait IDAO<TContractState> {
    fn propose(ref self: TContractState, description: felt252) -> u128;
    fn vote(ref self: TContractState, proposal_id: u128, support: bool);
    fn execute(ref self: TContractState, proposal_id: u128);
}

#[test]
fn test_dao_proposal() {
    // Deploy contract
    let contract = declare('DAO');
    let owner = starknet::contract_address_const::<0x123>();
    let token = starknet::contract_address_const::<0x456>();
    let constructor_calldata = array![owner.into(), token.into()];
    let dao_address = contract.deploy(@constructor_calldata).unwrap();
    let dao = IDAODispatcher { contract_address: dao_address };

    // Test proposal creation
    start_prank(dao_address, owner);
    let description: felt252 = 'Test Proposal';
    let proposal_id = dao.propose(description);
    assert(proposal_id == 1, 'Invalid proposal ID');
    stop_prank(dao_address);
}

#[test]
fn test_dao_voting() {
    // Deploy contract
    let contract = declare('DAO');
    let owner = starknet::contract_address_const::<0x123>();
    let token = starknet::contract_address_const::<0x456>();
    let constructor_calldata = array![owner.into(), token.into()];
    let dao_address = contract.deploy(@constructor_calldata).unwrap();
    let dao = IDAODispatcher { contract_address: dao_address };

    // Create proposal
    start_prank(dao_address, owner);
    let description: felt252 = 'Test Proposal';
    let proposal_id = dao.propose(description);

    // Test voting
    let voter = starknet::contract_address_const::<0x789>();
    start_prank(dao_address, voter);
    dao.vote(proposal_id, true);
    stop_prank(dao_address);
}

#[test]
#[should_panic(expected: ('Already voted', ))]
fn test_double_voting() {
    // Deploy contract
    let contract = declare('DAO');
    let owner = starknet::contract_address_const::<0x123>();
    let token = starknet::contract_address_const::<0x456>();
    let constructor_calldata = array![owner.into(), token.into()];
    let dao_address = contract.deploy(@constructor_calldata).unwrap();
    let dao = IDAODispatcher { contract_address: dao_address };

    // Create proposal
    start_prank(dao_address, owner);
    let proposal_id = dao.propose('Test Proposal');

    // Try to vote twice
    let voter = starknet::contract_address_const::<0x789>();
    start_prank(dao_address, voter);
    dao.vote(proposal_id, true);
    dao.vote(proposal_id, true); // Should panic
    stop_prank(dao_address);
}