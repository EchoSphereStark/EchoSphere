use starknet::ContractAddress;
use starknet::ClassHash;

// Define the contract interface for the main podcast platform features
#[starknet::interface]
pub trait IUserRegistry<TContractState> {
    fn set_is_creator(ref self: TContractState, is_creator: bool);
    fn favorite_episode(ref self: TContractState, episode_id: u256);
    fn unfavorite_episode(ref self: TContractState, episode_id: u256);
    fn upload_episode(ref self: TContractState, episode: Episode);
    fn subscribe_to_creator(ref self: TContractState, creator: ContractAddress);
    fn unsubscribe_from_creator(ref self: TContractState, creator: ContractAddress);
    fn get_subscribers(self: @TContractState, creator: ContractAddress) -> Array<ContractAddress>;
    fn tip_creator(ref self: TContractState, creator: ContractAddress, amount: u256);

    // Event hosting functions
    fn create_event(ref self: TContractState, event_details: EventDetails);
    fn buy_ticket(ref self: TContractState, event_id: u256);
    fn get_event(self: @TContractState, event_id: u256) -> EventDetails;
}

// Define the contract interface for upgradeability (from OpenZeppelin)
#[starknet::interface]
pub trait IUpgradeable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

// Define the contract module
#[starknet::contract]
pub mod PodcastPlatform {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use openzeppelin::token::erc721::interface::IERC721Dispatcher; 

    use starknet::get_caller_address;
    use starknet::storage::*;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use starknet::get_block_timestamp;
    use starknet::array::ArrayTrait;
    use starknet::vec::VecTrait;
    use starknet::Zeroable;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // === Dispatchers for external contracts ===
    // Dispatcher for the ERC20 tipping token
    // Dispatcher for external NFT contract (for episode NFTs)
    #[starknet::interface]
    trait IEpisodeNFT {
        fn mint(recipient: ContractAddress, token_id: u256);
    }
    // Dispatcher for external NFT contract (for event attendance NFTs)
    #[starknet::interface]
    trait IAttendanceNFT {
         // Assuming ERC721 for simplicity in buy_ticket function
        fn mint(recipient: ContractAddress, token_id: u256);
        // If using ERC1155, you might use:
        // fn safe_transfer_from(from: ContractAddress, to: ContractAddress, token_id: u256, value: u256, data: Span<felt252>);
    }


    // === Optional ByteArray wrapper ===
    #[derive(Copy, Drop, starknet::Store)]
    struct OptionByteArray {
        is_some: bool,
        value: ByteArray,
    }

    // === Content & User Structs ===
    #[derive(Copy, Drop, starknet::Store)]
    struct ContentMetadata {
        title: ByteArray,
        description: ByteArray,
        tags: Array<ByteArray>, // Changed Vec to Array for storage
        episode_number: u256,
        thumbnail: OptionByteArray,
        categories: Array<ByteArray>, // Changed Vec to Array for storage
    }

    #[derive(Copy, Drop, starknet::Store)]
    struct Episode {
        id: u256,
        metadata: ContentMetadata,
        creator: ContractAddress,
        publish_date: u64, // Using u64 for timestamp
        views: u256,
        episode_type: u256,
    }

    #[derive(Copy, Drop, starknet::Store)]
    struct Playlist {
        id: u128,
        title: ByteArray,
        description: ByteArray,
        episodes: Array<Episode>, // Changed Vec to Array for storage
    }

    #[derive(Copy, Drop, starknet::Store)]
    struct UserProfile {
        name: ByteArray,
        bio: ByteArray,
        profile_photo: ByteArray,
        banner_image: ByteArray,
        social_links: ByteArray,
        episode_nft_contract: ContractAddress, // Address of the episode NFT contract for this user/creator
        subscribers: Array<ContractAddress>, // Changed Vec to Array for storage
        playlists: Array<Playlist>, // Changed Vec to Array for storage
        // Add a field to track if the user is a creator
        is_creator: bool,
    }

    // === Event Struct ===
    #[derive(Copy, Drop, starknet::Store)]
    struct EventDetails {
        id: u256,
        creator: ContractAddress,
        title: ByteArray,
        description: ByteArray,
        start_time: u64, // Using u64 for timestamp
        end_time: u64, // Using u64 for timestamp
        location: ByteArray,
        attendance_nft_contract: ContractAddress, // Address of the NFT contract for this event
        // Add other fields as needed (e.g., ticket types, pricing, capacity)
    }


    // === Storage ===
    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        tipping_token: ContractAddress,

        users: Map<ContractAddress, UserProfile>,
        favorites: Map<(ContractAddress, u256), bool>, // (user, episode_id) -> is_favorite
        episodes: Map<u256, Episode>, // episode_id -> Episode

        // Storage for events
        events: Map<u256, EventDetails>, // event_id -> EventDetails
        next_event_id: u256, // Counter for generating unique event IDs
    }

    // === Events ===
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CreatorStatusSet: CreatorStatusSet,
        FavoriteAdded: FavoriteAdded,
        FavoriteRemoved: FavoriteRemoved,
        // FollowAdded: (ContractAddress, ContractAddress), // Not implemented in provided code
        // FollowRemoved: (ContractAddress, ContractAddress), // Not implemented in provided code
        TipSent: TipSent,
        EpisodeUploaded: EpisodeUploaded,
        SubscribeToCreator: SubscribeToCreator,
        UnsubscribeFromCreator: UnsubscribeFromCreator,
        EventCreated: EventCreated,
        TicketPurchased: TicketPurchased,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreatorStatusSet {
        user: ContractAddress,
        is_creator: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FavoriteAdded {
        user: ContractAddress,
        episode_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FavoriteRemoved {
        user: ContractAddress,
        episode_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TipSent {
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EpisodeUploaded {
        creator: ContractAddress,
        episode_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscribeToCreator {
        subscriber: ContractAddress,
        creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UnsubscribeFromCreator {
        unsubscriber: ContractAddress,
        creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventCreated {
        event_id: u256,
        creator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TicketPurchased {
        event_id: u256,
        user: ContractAddress,
        // Maybe ticket_type_id if using ERC1155
    }


    // === Constructor ===
    #[constructor]
    fn constructor(ref self: ContractState, tipping_token: ContractAddress, owner: ContractAddress) {
        self.tipping_token.write(tipping_token);
        self.ownable.initializer(owner);
        self.next_event_id.write(0); // Initialize event ID counter
    }

    // === Implementation of IUserRegistry Interface ===
    // Functions defined here are public and callable from outside
    #[abi(embed_v0)]
    pub impl PodcastPlatformImpl of super::IUserRegistry<ContractState> {
        use super::IEpisodeNFTDispatcher;
        use openzeppelin::token::erc20::interface::IERC20Dispatcher;
        use super::IAttendanceNFTDispatcher;

        fn set_is_creator(ref self: ContractState, is_creator: bool) {
            let caller = get_caller_address();
            let mut profile = self.users.read(caller);
            profile.is_creator = is_creator; // Store creator status
            self.users.write(caller, profile);
            self.emit(Event::CreatorStatusSet(CreatorStatusSet { user: caller, is_creator }));
        }

        fn favorite_episode(ref self: ContractState, episode_id: u256) {
            let caller = get_caller_address();
            self.favorites.write((caller, episode_id), true);
            self.emit(Event::FavoriteAdded(FavoriteAdded { user: caller, episode_id }));
        }

        fn unfavorite_episode(ref self: ContractState, episode_id: u256) {
            let caller = get_caller_address();
            self.favorites.write((caller, episode_id), false);
            self.emit(Event::FavoriteRemoved(FavoriteRemoved { user: caller, episode_id }));
        }

        fn upload_episode(ref self: ContractState, episode_details: Episode) {
            let caller = get_caller_address();
            let user_profile = self.users.read(caller);

            // Ensure caller is a creator (optional check)
            // assert(user_profile.is_creator, 'Only creators can upload episodes');

            // Write the episode to storage
            self.episodes.write(episode_details.id, episode_details);

            // Mint NFT for the episode using the creator's specified contract
            assert(!user_profile.episode_nft_contract.is_zero(), 'Creator NFT contract not set');
            let episode_nft_dispatcher = IEpisodeNFTDispatcher { contract_address: user_profile.episode_nft_contract };
            episode_nft_dispatcher.mint(caller, episode_details.id);

            self.emit(Event::EpisodeUploaded(EpisodeUploaded { creator: caller, episode_id: episode_details.id }));
        }

        fn subscribe_to_creator(ref self: ContractState, creator: ContractAddress) {
            let caller = get_caller_address();
            let mut profile = self.users.read(creator);

            // Ensure the creator exists and is marked as a creator (optional check)
            // assert(!profile.is_zero(), 'Creator profile does not exist');
            // assert(profile.is_creator, 'Address is not a creator');

            // Check if already subscribed (optional)
            // assert(!profile.subscribers.contains(caller), 'Already subscribed');

            profile.subscribers.append(caller);
            self.users.write(creator, profile);
            self.emit(Event::SubscribeToCreator(SubscribeToCreator { subscriber: caller, creator }));
        }

        fn unsubscribe_from_creator(ref self: ContractState, creator: ContractAddress) {
            let caller = get_caller_address();
            let mut profile = self.users.read(creator);

             // Ensure the creator exists (optional check)
            // assert(!profile.is_zero(), 'Creator profile does not exist');

            // Retain subscribers whose address is not the caller's
            profile.subscribers.retain(|addr| *addr != caller);
            self.users.write(creator, profile);
            self.emit(Event::UnsubscribeFromCreator(UnsubscribeFromCreator { unsubscriber: caller, creator }));
        }

        fn get_subscribers(self: @ContractState, creator: ContractAddress) -> Array<ContractAddress> {
            self.users.read(creator).subscribers
        }

        fn tip_creator(ref self: ContractState, creator: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let token_contract_address = self.tipping_token.read();

            // Ensure tipping token address is set
            assert(!token_contract_address.is_zero(), 'Tipping token not set');

            let token_dispatcher = IERC20Dispatcher { contract_address: token_contract_address };
            token_dispatcher.transfer_from(caller, creator, amount);
            self.emit(Event::TipSent(TipSent { sender: caller, recipient: creator, amount }));
        }

        // === Event Hosting and Attendance Minting Functions ===

        fn create_event(ref self: ContractState, event_details: EventDetails) {
            let caller = get_caller_address();
            let mut user_profile = self.users.read(caller);

            // Ensure caller is a creator (optional check)
            // assert(user_profile.is_creator, 'Only creators can create events');

            let event_id = self.next_event_id.read();

            let mut new_event = event_details;
            new_event.id = event_id;
            new_event.creator = caller; // Ensure creator is the caller

            // Basic validation (optional)
            assert(!new_event.attendance_nft_contract.is_zero(), 'Attendance NFT contract must be set');
            assert(new_event.start_time < new_event.end_time, 'Event end time must be after start time');
            // Add more validation as needed

            self.events.write(event_id, new_event);
            self.next_event_id.write(event_id + 1); // Increment event ID counter

            self.emit(Event::EventCreated(EventCreated { event_id, creator: caller }));
        }

        fn buy_ticket(ref self: ContractState, event_id: u256) {
            let caller = get_caller_address();
            let event = self.events.read(event_id);

            // Ensure event exists (check for zero values if not found)
            assert(!event.creator.is_zero(), 'Event does not exist');

            // Interact with the event's specific attendance NFT contract
            assert(!event.attendance_nft_contract.is_zero(), 'Event Attendance NFT contract not set');
            let attendance_nft_dispatcher = IAttendanceNFTDispatcher { contract_address: event.attendance_nft_contract };

            // Mint an NFT to the caller for this event
            // The token_id could represent the event_id, or a combination of event_id and user/ticket type
            // This simple example uses event_id as the token_id for the attendance NFT
            attendance_nft_dispatcher.mint(caller, event_id); // Simple example using event_id as token_id

            self.emit(Event::TicketPurchased(TicketPurchased { event_id, user: caller }));
        }

        fn get_event(self: @ContractState, event_id: u256) -> EventDetails {
            self.events.read(event_id)
        }
    }

    // === Implementation of IUpgradeable Interface (from OpenZeppelin) ===
    #[abi(embed_v0)]
    impl UpgradeableImpl of super::IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner(); // Only owner can upgrade
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}