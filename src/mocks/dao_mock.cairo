use starknet::ContractAddress;
use starknet::storage::*;
use starknet::get_caller_address;
use starknet::Zeroable;

#[starknet::interface]
pub trait IDAO<TContractState> {
    fn is_proposal_executed(self: @TContractState, proposal_id: u128) -> bool;
}

#[starknet::contract]
pub mod DAOMock {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;
    use starknet::Zeroable;

    #[storage]
    pub struct Storage {
        // Map to store executed proposal IDs for mocking purposes
        executed_proposals: Map<u128, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        IsProposalExecutedCalled: IsProposalExecutedCalled,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IsProposalExecutedCalled {
        proposal_id: u128,
    }

    #[abi(embed_v0)]
    pub impl IDAOMockImpl of super::IDAO<ContractState> {
        fn is_proposal_executed(self: @ContractState, proposal_id: u128) -> bool {
            // Emit event to signal this function was called
            self.emit(Event::IsProposalExecutedCalled(IsProposalExecutedCalled { proposal_id }));
            // Return the mocked execution status
            self.executed_proposals.read(proposal_id)
        }
    }

    // Helper function to set mocked execution status (internal, for testing)
    #[generate_trait]
    pub impl InternalTraitImpl of InternalTrait {
        fn set_executed_status(ref self: ContractState, proposal_id: u128, status: bool) {
            self.executed_proposals.write(proposal_id, status);
        }
    }
}