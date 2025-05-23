// #[starknet::contract]
// mod DAO {
//     use starknet::ContractAddress;
//     use openzeppelin::token::erc20::interface::IERC20;
//     use openzeppelin::access::ownable::OwnableComponent;

//     component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

//     #[storage]
//     struct Storage {
//         proposal_count: u128,
//         proposals: LegacyMap<u128, Proposal>,
//         has_voted: LegacyMap<(ContractAddress, u128), bool>,
//         token: ContractAddress,
//         #[substorage(v0)]
//         ownable: OwnableComponent::Storage
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     enum Event {
//         OwnableEvent: OwnableComponent::Event
//     }

//     #[derive(Drop, Serde, Copy)]
//     struct Proposal {
//         description: felt252,
//         votes_for: u128,
//         votes_against: u128,
//         executed: bool,
//     }

//     #[constructor]
//     fn constructor(
//         ref self: ContractState,
//         owner: ContractAddress,
//         token: ContractAddress
//     ) {
//         self.ownable.initializer(owner);
//         self.token.write(token);
//     }

//     #[abi]
//     impl IDAOImpl of IDAO<ContractState> {
//         fn propose(ref self: ContractState, description: felt252) -> u128 {
//             self.ownable.assert_only_owner();
            
//             let mut count = self.proposal_count.read();
//             count += 1;
            
//             let proposal = Proposal {
//                 description,
//                 votes_for: 0,
//                 votes_against: 0,
//                 executed: false
//             };
            
//             self.proposals.write(count, proposal);
//             self.proposal_count.write(count);
//             count
//         }

//         fn vote(ref self: ContractState, proposal_id: u128, support: bool) {
//             let caller = self.get_caller_address();
//             assert(!self.has_voted.read((caller, proposal_id)), 'Already voted');
            
//             let mut proposal = self.proposals.read(proposal_id);
//             assert(!proposal.executed, 'Proposal executed');
            
//             let voting_power = IERC20Dispatcher { contract_address: self.token.read() }.balance_of(caller);
//             assert(voting_power > 0, 'No voting power');
            
//             if support {
//                 proposal.votes_for += voting_power;
//             } else {
//                 proposal.votes_against += voting_power;
//             }
            
//             self.proposals.write(proposal_id, proposal);
//             self.has_voted.write((caller, proposal_id), true);
//         }

//         fn execute(ref self: ContractState, proposal_id: u128) {
//             let mut proposal = self.proposals.read(proposal_id);
//             assert(!proposal.executed, 'Proposal executed');
//             assert(proposal.votes_for > proposal.votes_against, 'Not approved');
            
//             proposal.executed = true;
//             self.proposals.write(proposal_id, proposal);
            
            
//         }
//     }

//     #[generate_trait]
//     impl OwnableImpl of OwnableComponent::Impl<ContractState> {
//         fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
//             self.ownable.transfer_ownership(new_owner);
//         }
//     }
// }