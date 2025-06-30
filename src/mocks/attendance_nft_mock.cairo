// attendance_nft_mock.cairo
use starknet::ContractAddress;
use starknet::storage::*;
use starknet::get_caller_address;
use starknet::Zeroable;
use starknet::array::ArrayTrait;

#[starknet::interface]
pub trait IAttendanceNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::contract]
pub mod AttendanceNFTMock {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;
    use starknet::Zeroable;
    use starknet::array::ArrayTrait;

    #[storage]
    pub struct Storage {
        // Simple mapping to track minted tokens
        owner_of: Map<u256, ContractAddress>, // token_id -> owner
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MintCalled: MintCalled,
        Transfer: Transfer, // Standard ERC721 Transfer event
    }

    #[derive(Drop, starknet::Event)]
    pub struct MintCalled {
        caller: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
    }

     #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress, // Zero address for minting
        to: ContractAddress,
        token_id: u256,
    }

    #[abi(embed_v0)]
    pub impl IAttendanceNFTMockImpl of super::IAttendanceNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            let caller = get_caller_address();
            // Emit event to signal this function was called
            self.emit(Event::MintCalled(MintCalled { caller, recipient, token_id }));

            // Basic minting logic for testing
            assert!(self.owner_of.read(token_id).is_zero(), 'NFT already minted');
            self.owner_of.write(token_id, recipient);

            // Emit standard Transfer event (from zero address)
            let zero_address = Zeroable::zero();
            self.emit(Event::Transfer(Transfer { from: zero_address, to: recipient, token_id }));
        }
    }
}