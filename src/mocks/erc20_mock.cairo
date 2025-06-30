use starknet::ContractAddress;
use starknet::storage::*;
use starknet::get_caller_address;
use starknet::Zeroable;
use starknet::array::ArrayTrait;
use starknet::felt252_span;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256);
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    // Add other ERC20 functions if needed for tests
}

#[starknet::contract]
pub mod ERC20Mock {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;
    use starknet::Zeroable;
    use starknet::array::ArrayTrait;
    use starknet::felt252_span;
    use integer::u256_safe_add;

    #[storage]
    pub struct Storage {
        balances: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TransferFromCalled: TransferFromCalled,
        Transfer: Transfer, // Standard ERC20 Transfer event
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferFromCalled {
        caller: ContractAddress,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }


    #[abi(embed_v0)]
    pub impl IERC20MockImpl of super::IERC20<ContractState> {
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            // Emit event to signal this function was called
            self.emit(Event::TransferFromCalled(TransferFromCalled { caller, sender, recipient, amount }));

            // Basic balance logic for testing
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, 'ERC20Mock: Insufficient balance');
            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, u256_safe_add(recipient_balance, amount).unwrap());

            // Emit standard Transfer event
            self.emit(Event::Transfer(Transfer { from: sender, to: recipient, value: amount }));
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }
    }

    // Helper function to set mocked balance (internal, for testing)
    #[generate_trait]
    pub impl InternalTraitImpl of InternalTrait {
        fn set_balance(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.balances.write(account, amount);
        }
    }
}