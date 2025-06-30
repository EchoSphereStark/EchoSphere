use starknet::ContractAddress;
use openzeppelin::token::erc20::interface::IERC20Dispatcher; // Use Dispatcher
use openzeppelin::access::ownable::OwnableComponent;

// Define the contract interface for the DAO
#[starknet::interface]
pub trait IDAO<TContractState> {
    fn propose(ref self: TContractState, description: felt252) -> u128;
    fn vote(ref self: TContractState, proposal_id: u128, support: bool);
    fn execute(ref self: TContractState, proposal_id: u128);
    // Added view function for external contracts to check proposal status
    fn is_proposal_executed(self: @TContractState, proposal_id: u128) -> bool;
}


#[starknet::contract]
pub mod DAO {
    // Always use full paths for core library imports.
    use starknet::ContractAddress;
    // Always add all storage imports
    use starknet::storage::*;
    // Add library function depending on context
    use starknet::get_caller_address;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::Zeroable; // Added Zeroable for checks

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[storage]
    pub struct Storage {
        proposal_count: u128,
        proposals: LegacyMap<u128, Proposal>, // Keeping LegacyMap as provided
        has_voted: LegacyMap<(ContractAddress, u128), bool>, // Keeping LegacyMap as provided
        token: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OwnableEvent: OwnableComponent::Event,
        // Add specific DAO events if needed (e.g., ProposalCreated, Voted, ProposalExecuted)
        ProposalCreated: ProposalCreated,
        Voted: Voted,
        ProposalExecuted: ProposalExecuted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalCreated {
        proposal_id: u128,
        description: felt252,
        proposer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Voted {
        proposal_id: u128,
        voter: ContractAddress,
        support: bool,
        voting_power: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalExecuted {
        proposal_id: u128,
    }


    #[derive(Drop, Serde, Copy, starknet::Store)] // Added starknet::Store for potential future use in other structs
    pub struct Proposal {
        description: felt252,
        votes_for: u128,
        votes_against: u128,
        executed: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        token: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.token.write(token);
        self.proposal_count.write(0); // Initialize proposal count
    }

    // Use #[abi(embed_v0)] for public interface implementations
    #[abi(embed_v0)]
    pub impl IDAOImpl of super::IDAO<ContractState> {
        fn propose(ref self: ContractState, description: felt252) -> u128 {
            // Keep assert_only_owner() as per provided code, implying DAO creation/basic setup is owned
            self.ownable.assert_only_owner();

            let mut count = self.proposal_count.read();
            count += 1;

            let proposal = Proposal {
                description,
                votes_for: 0,
                votes_against: 0,
                executed: false
            };

            self.proposals.write(count, proposal);
            self.proposal_count.write(count);

            let caller = get_caller_address();
            self.emit(Event::ProposalCreated(ProposalCreated { proposal_id: count, description, proposer: caller }));

            count
        }

        fn vote(ref self: ContractState, proposal_id: u128, support: bool) {
            let caller = get_caller_address(); // Use get_caller_address from imports
            assert(!self.has_voted.read((caller, proposal_id)), 'Already voted');

            let mut proposal = self.proposals.read(proposal_id);
            assert(!proposal.executed, 'Proposal executed');
            // Check if proposal exists
            assert(!proposal.description.is_zero(), 'Proposal does not exist'); // Assuming description is not zero for valid proposal

            let voting_power = IERC20Dispatcher { contract_address: self.token.read() }.balance_of(caller);
            assert(voting_power > 0, 'No voting power');

            if support {
                proposal.votes_for += voting_power;
            } else {
                proposal.votes_against += voting_power;
            }

            self.proposals.write(proposal_id, proposal);
            self.has_voted.write((caller, proposal_id), true);

            self.emit(Event::Voted(Voted { proposal_id, voter: caller, support, voting_power }));
        }

        fn execute(ref self: ContractState, proposal_id: u128) {
            let mut proposal = self.proposals.read(proposal_id);
            assert(!proposal.executed, 'Proposal executed');
             // Check if proposal exists
            assert(!proposal.description.is_zero(), 'Proposal does not exist'); // Assuming description is not zero for valid proposal
            assert(proposal.votes_for > proposal.votes_against, 'Not approved'); // Basic approval check

            proposal.executed = true;
            self.proposals.write(proposal_id, proposal);

            self.emit(Event::ProposalExecuted(ProposalExecuted { proposal_id }));

            // In a real DAO, execution logic (calling other contracts) would go here.
            // For this integration, the PodcastPlatform contract checks the 'executed' status.
        }

        // View function to check execution status
        fn is_proposal_executed(self: @ContractState, proposal_id: u128) -> bool {
             let proposal = self.proposals.read(proposal_id);
             // Return true only if proposal exists and is executed
             !proposal.description.is_zero() && proposal.executed
        }
    }

    // Internal implementation for Ownable component, kept as provided
    #[generate_trait]
    pub impl OwnableInternalImpl of OwnableComponent::InternalTrait<ContractState> {
        fn initializer(ref self: ComponentState<ContractState>, owner: ContractAddress) {
            self.initializer(owner);
        }

        fn assert_only_owner(self: @ComponentState<ContractState>) {
            self.assert_only_owner();
        }

        fn _transfer_ownership(
            ref self: ComponentState<ContractState>, new_owner: ContractAddress
        ) {
             self._transfer_ownership(new_owner);
        }
    }

    // Alias for the embeddable Ownable implementation, kept as provided but #[abi] removed
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
}