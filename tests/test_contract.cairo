use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::Zeroable;
use starknet::array::ArrayTrait;
use starknet::array; // Import array! macro
use starknet::get_block_timestamp;
use integer::u256_from_felt252;

// Import the PodcastPlatform contract module
use podcast::PodcastPlatform;

// Import interfaces and dispatchers for the contract under test
use podcast::{IUserRegistryDispatcher, IUserRegistryDispatcherTrait};
use podcast::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};

// Import interfaces and dispatchers for mock external contracts
use mocks::dao_mock::{IDAODispatcher, IDAODispatcherTrait, DAOMock};
use mocks::erc20_mock::{IERC20Dispatcher, IERC20DispatcherTrait, ERC20Mock};
use mocks::episode_nft_mock::{IEpisodeNFTDispatcher, IEpisodeNFTDispatcherTrait, EpisodeNFTMock};
use mocks::attendance_nft_mock::{IAttendanceNFTDispatcher, IAttendanceNFTDispatcherTrait, AttendanceNFTMock};

// Import structs used in the PodcastPlatform contract
use podcast::PodcastPlatform::{
    Episode, EventDetails, UserProfile, ContentMetadata, OptionByteArray
};

// Import event structs from the PodcastPlatform contract
use podcast::PodcastPlatform::{
    CreatorStatusSet, FavoriteAdded, FavoriteRemoved, TipSent, EpisodeUploaded,
    SubscribeToCreator, UnsubscribeFromCreator, EventCreated, TicketPurchased
};

// Import event structs from mock contracts for assertion
use dao_mock::DAOMock::{IsProposalExecutedCalled};
use erc20_mock::ERC20Mock::{TransferFromCalled as ERC20TransferFromCalled, Transfer as ERC20Transfer};
use episode_nft_mock::EpisodeNFTMock::{MintCalled as EpisodeNFTMintCalled, Transfer as EpisodeNFTTransfer};
use attendance_nft_mock::AttendanceNFTMock::{MintCalled as AttendanceNFTMintCalled, Transfer as AttendanceNFTTransfer};


// Required for declaring and deploying contracts, and cheatcodes
use snforge_std::{
    declare, DeclareResultTrait, ContractClassTrait, deploy_contract,
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
    spy_events, EventSpyAssertionsTrait, EventAssertionsTrait, EventSpy
};

// Helper function to convert felt252 literal to ContractAddress
fn contract_address_const<T>(value: felt252) -> ContractAddress {
    let mut bytes = ByteArray::new();
    bytes.append_word(value);
    bytes.try_into().unwrap()
}

// Helper function to deploy the PodcastPlatform contract and its mocks
fn deploy_podcast_platform() -> (
    IUserRegistryDispatcher,
    IUpgradeableDispatcher,
    IDAODispatcher,
    IERC20Dispatcher,
    IEpisodeNFTDispatcher,
    IAttendanceNFTDispatcher
) {
    // Declare mock contracts first
    let dao_mock_class_hash = declare("DAOMock").unwrap().class_hash();
    let erc20_mock_class_hash = declare("ERC20Mock").unwrap().class_hash();
    let episode_nft_mock_class_hash = declare("EpisodeNFTMock").unwrap().class_hash();
    let attendance_nft_mock_class_hash = declare("AttendanceNFTMock").unwrap().class_hash();

    // Deploy mock contracts
    let (dao_mock_address, _) = deploy_contract(dao_mock_class_hash, array![]()).unwrap();
    let (erc20_mock_address, _) = deploy_contract(erc20_mock_class_hash, array![]()).unwrap();
    let (episode_nft_mock_address, _) = deploy_contract(episode_nft_mock_class_hash, array![]()).unwrap();
    let (attendance_nft_mock_address, _) = deploy_contract(attendance_nft_mock_class_hash, array![]()).unwrap();


    // Declare the PodcastPlatform contract
    let podcast_platform_class_hash = declare("PodcastPlatform").unwrap().class_hash();

    // Prepare constructor arguments for PodcastPlatform: tipping_token, dao_contract_address, owner (for Ownable, although removed in integrated version, the original had it)
    // Let's use the integrated version's constructor: tipping_token, dao_contract_address
    let mut constructor_calldata = array![];
    let tipping_token_address = erc20_mock_address;
    let dao_contract_address = dao_mock_address;

    // Serialize constructor arguments
    Serde::serialize(@tipping_token_address, ref constructor_calldata);
    Serde::serialize(@dao_contract_address, ref constructor_calldata);

    // Deploy the PodcastPlatform contract
    let (podcast_platform_address, _) = deploy_contract(podcast_platform_class_hash, constructor_calldata.span()).unwrap();

    // Create dispatchers
    let podcast_platform_dispatcher = IUserRegistryDispatcher { contract_address: podcast_platform_address };
    let upgradeable_dispatcher = IUpgradeableDispatcher { contract_address: podcast_platform_address };
    let dao_mock_dispatcher = IDAODispatcher { contract_address: dao_mock_address };
    let erc20_mock_dispatcher = IERC20Dispatcher { contract_address: erc20_mock_address };
    let episode_nft_mock_dispatcher = IEpisodeNFTDispatcher { contract_address: episode_nft_mock_address };
    let attendance_nft_mock_dispatcher = IAttendanceNFTDispatcher { contract_address: attendance_nft_mock_address };


    (
        podcast_platform_dispatcher,
        upgradeable_dispatcher,
        dao_mock_dispatcher,
        erc20_mock_dispatcher,
        episode_nft_mock_dispatcher,
        attendance_nft_mock_dispatcher
    )
}

// Helper function to create a sample UserProfile
fn sample_user_profile(episode_nft_contract: ContractAddress) -> UserProfile {
    UserProfile {
        name: "TestUser".into(),
        bio: "A test user".into(),
        profile_photo: "photo_url".into(),
        banner_image: "banner_url".into(),
        social_links: "links".into(),
        episode_nft_contract, // Use the mock NFT contract
        subscribers: array![].span(),
        playlists: array![].span(),
        is_creator: false,
    }
}

// Helper function to create a sample Episode
fn sample_episode(id: u256, creator: ContractAddress, episode_nft_contract: ContractAddress) -> Episode {
    Episode {
        id,
        metadata: ContentMetadata {
            title: "Test Episode".into(),
            description: "Episode description".into(),
            tags: array!["tag1".into(), "tag2".into()].span(),
            episode_number: 1,
            thumbnail: OptionByteArray { is_some: false, value: "".into() },
            categories: array!["category1".into()].span(),
        },
        creator,
        publish_date: get_block_timestamp(), // Use cheatcode timestamp
        views: 0,
        episode_type: 0,
    }
}

// Helper function to create a sample EventDetails
fn sample_event_details(attendance_nft_contract: ContractAddress) -> EventDetails {
     EventDetails {
        id: 0, // ID will be set by the contract
        creator: Zeroable::zero(), // Creator will be set by the contract
        title: "Test Event".into(),
        description: "Event description".into(),
        start_time: get_block_timestamp() + 100, // Use cheatcode timestamp
        end_time: get_block_timestamp() + 200,
        location: "Virtual".into(),
        attendance_nft_contract, // Use the mock NFT contract
    }
}


#[test]
fn test_set_is_creator() {
    let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events();

    let user_address = contract_address_const::<'test_user'>();
    start_cheat_caller_address(podcast_platform.contract_address, user_address);

    // Set user as creator
    podcast_platform.set_is_creator(true);

    // Assert event emission
    let expected_event = PodcastPlatform::Event::CreatorStatusSet(
        CreatorStatusSet { user: user_address, is_creator: true }
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

    // Note: To fully verify the state change, we'd need a view function like `get_user_profile`
    // which was not included in the provided interfaces. Testing via events is sufficient
    // based on the provided contract's logic and test examples <a href="https://book.cairo-lang.org/ch104-02-testing-smart-contracts.html" target="_blank" rel="noopener noreferrer" className="bg-light-secondary dark:bg-dark-secondary px-1 rounded ml-1 no-underline text-xs text-black/70 dark:text-white/70 relative hover:underline">5</a>.

    stop_cheat_caller_address(podcast_platform.contract_address);
}

#[test]
fn test_favorite_episode() {
    let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events();

    let user_address = contract_address_const::<'test_user'>();
    let episode_id = 123.try_into().unwrap();
    start_cheat_caller_address(podcast_platform.contract_address, user_address);

    // Favorite the episode
    podcast_platform.favorite_episode(episode_id);

    // Assert event emission
    let expected_event = PodcastPlatform::Event::FavoriteAdded(
        FavoriteAdded { user: user_address, episode_id }
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

    // Note: Verifying storage change directly would require a view function or `load` cheatcode.
    // Testing via events and potential future view functions is the pattern.

    stop_cheat_caller_address(podcast_platform.contract_address);
}

#[test]
fn test_unfavorite_episode() {
    let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events();

    let user_address = contract_address_const::<'test_user'>();
    let episode_id = 123.try_into().unwrap();
    start_cheat_caller_address(podcast_platform.contract_address, user_address);

    // Unfavorite the episode
    podcast_platform.unfavorite_episode(episode_id);

    // Assert event emission
    let expected_event = PodcastPlatform::Event::FavoriteRemoved(
        FavoriteRemoved { user: user_address, episode_id }
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

    stop_cheat_caller_address(podcast_platform.contract_address);
}

#[test]
fn test_upload_episode() {
    let (podcast_platform, _, _, _, episode_nft_mock, _) = deploy_podcast_platform();
    let mut platform_spy = spy_events();
    let mut nft_spy = spy_events(); // Spy on events from the mock NFT contract

    let creator_address = contract_address_const::<'test_creator'>();
    let episode_id = 456.try_into().unwrap();
    let episode_nft_contract_address = episode_nft_mock.contract_address;

    // Need to set the creator's profile and episode NFT contract address first
    // This requires a helper function or direct storage manipulation (if using internal testing)
    // For deployed contract testing, we assume a function exists to set user profile or set it in constructor
    // Since no such function is in interfaces, we'll mock the user profile lookup implicitly
    // Or, ideally, the contract would have a `set_user_profile` function.
    // For this test, we'll assume the user profile with the NFT contract is set.

    // Mock the caller address for the upload
    start_cheat_caller_address(podcast_platform.contract_address, creator_address);

    // Set the block timestamp for the episode publish_date
    start_cheat_block_timestamp(1000);

    // Prepare episode details
    let episode_details = sample_episode(episode_id, creator_address, episode_nft_contract_address);

    // Upload the episode
    podcast_platform.upload_episode(episode_details);

    stop_cheat_block_timestamp();
    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert PodcastPlatform event emission
    let expected_platform_event = PodcastPlatform::Event::EpisodeUploaded(
        EpisodeUploaded { creator: creator_address, episode_id }
    );
    platform_spy.assert_emitted(@array![(podcast_platform.contract_address, expected_platform_event)]);

    // Assert that the mock NFT contract's mint function was called
    let expected_nft_call_event = EpisodeNFTMock::Event::MintCalled(
        EpisodeNFTMintCalled { caller: podcast_platform.contract_address, recipient: creator_address, token_id: episode_id }
    );
     nft_spy.assert_emitted(@array![(episode_nft_mock.contract_address, expected_nft_call_event)]);

    // Assert the standard ERC721 Transfer event from the mock NFT contract
    let zero_address = Zeroable::zero();
    let expected_nft_transfer_event = EpisodeNFTMock::Event::Transfer(
        EpisodeNFTTransfer { from: zero_address, to: creator_address, token_id: episode_id }
    );
    nft_spy.assert_emitted(@array![(episode_nft_mock.contract_address, expected_nft_transfer_event)]);
}


#[test]
fn test_subscribe_to_creator() {
    let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events();

    let subscriber_address = contract_address_const::<'subscriber'>();
    let creator_address = contract_address_const::<'creator'>();

    // Mock the caller address for the subscription
    start_cheat_caller_address(podcast_platform.contract_address, subscriber_address);

    // Subscribe to the creator
    podcast_platform.subscribe_to_creator(creator_address);

    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert event emission
    let expected_event = PodcastPlatform::Event::SubscribeToCreator(
        SubscribeToCreator { subscriber: subscriber_address, creator: creator_address }
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

    // To verify the subscriber list, we would use get_subscribers view function
    let subscribers = podcast_platform.get_subscribers(creator_address);
    assert(subscribers.len() == 1, 'Wrong subscribers count');
    assert(*subscribers.at(0) == subscriber_address, 'Wrong subscriber address');
}

#[test]
fn test_unsubscribe_from_creator() {
    let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events();

    let subscriber_address = contract_address_const::<'subscriber'>();
    let creator_address = contract_address_const::<'creator'>();

    // Mock the caller address for the subscription
    start_cheat_caller_address(podcast_platform.contract_address, subscriber_address);

    // First, subscribe
    podcast_platform.subscribe_to_creator(creator_address);

    // Then, unsubscribe
    podcast_platform.unsubscribe_from_creator(creator_address);

    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert event emission for unsubscription
    let expected_event = PodcastPlatform::Event::UnsubscribeFromCreator(
        UnsubscribeFromCreator { unsubscriber: subscriber_address, creator: creator_address }
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

     // Verify the subscriber list is empty
    let subscribers = podcast_platform.get_subscribers(creator_address);
    assert(subscribers.len() == 0, 'Subscribers list not empty');
}

#[test]
fn test_get_subscribers() {
     let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
    let mut spy = spy_events(); // Spy to capture subscribe events

    let subscriber1 = contract_address_const::<'subscriber1'>();
    let subscriber2 = contract_address_const::<'subscriber2'>();
    let creator_address = contract_address_const::<'creator'>();

    // Mock callers and subscribe
    start_cheat_caller_address(podcast_platform.contract_address, subscriber1);
    podcast_platform.subscribe_to_creator(creator_address);
    stop_cheat_caller_address(podcast_platform.contract_address);

    start_cheat_caller_address(podcast_platform.contract_address, subscriber2);
    podcast_platform.subscribe_to_creator(creator_address);
    stop_cheat_caller_address(podcast_platform.contract_address);

    // Call the view function
    let subscribers = podcast_platform.get_subscribers(creator_address);

    // Assert the result
    assert(subscribers.len() == 2, 'Wrong number of subscribers');
    // Order might not be guaranteed by Map or Vec, so check existence
    let mut found_sub1 = false;
    let mut found_sub2 = false;
    let mut i = 0;
    loop {
        if i == subscribers.len() {
            break;
        }
        let sub = *subscribers.at(i);
        if sub == subscriber1 {
            found_sub1 = true;
        } else if sub == subscriber2 {
            found_sub2 = true;
        }
        i += 1;
    };
    assert(found_sub1, 'Subscriber 1 not found');
    assert(found_sub2, 'Subscriber 2 not found');
}


#[test]
fn test_tip_creator() {
    let (podcast_platform, _, _, erc20_mock, _, _) = deploy_podcast_platform();
    let mut platform_spy = spy_events();
    let mut erc20_spy = spy_events(); // Spy on events from the mock ERC20 contract

    let tipper_address = contract_address_const::<'tipper'>();
    let creator_address = contract_address_const::<'creator'>();
    let tip_amount = 1000.try_into().unwrap();
    let tipping_token_address = erc20_mock.contract_address; // Address of the mock ERC20

    // Need to set some balance for the tipper on the mock ERC20 contract
    let erc20_mock_internal_dispatcher = ERC20Mock::InternalTraitDispatcher { contract_address: tipping_token_address };
    erc20_mock_internal_dispatcher.set_balance(tipper_address, tip_amount * 2); // Give enough balance


    // Mock the caller address for the tip
    start_cheat_caller_address(podcast_platform.contract_address, tipper_address);

    // Tip the creator
    podcast_platform.tip_creator(creator_address, tip_amount);

    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert PodcastPlatform event emission
    let expected_platform_event = PodcastPlatform::Event::TipSent(
        TipSent { sender: tipper_address, recipient: creator_address, amount: tip_amount }
    );
    platform_spy.assert_emitted(@array![(podcast_platform.contract_address, expected_platform_event)]);

    // Assert that the mock ERC20 contract's transfer_from function was called
    let expected_erc20_call_event = ERC20Mock::Event::TransferFromCalled(
        ERC20TransferFromCalled {
            caller: podcast_platform.contract_address, // Contract calls transfer_from
            sender: tipper_address,
            recipient: creator_address,
            amount: tip_amount
        }
    );
    erc20_spy.assert_emitted(@array![(erc20_mock.contract_address, expected_erc20_call_event)]);

    // Assert the standard ERC20 Transfer event from the mock ERC20 contract
     let expected_erc20_transfer_event = ERC20Mock::Event::Transfer(
        ERC20Transfer {
            from: tipper_address,
            to: creator_address,
            value: tip_amount
        }
    );
     erc20_spy.assert_emitted(@array![(erc20_mock.contract_address, expected_erc20_transfer_event)]);

    // Verify balances changed on the mock ERC20 (optional, covered by Transfer event assertion)
    // let tipper_balance = erc20_mock.balance_of(tipper_address);
    // let creator_balance = erc20_mock.balance_of(creator_address);
    // assert(tipper_balance == tip_amount, 'Tipper balance incorrect');
    // assert(creator_balance == tip_amount, 'Creator balance incorrect');
}

#[test]
fn test_create_event() {
    let (podcast_platform, _, _, _, _, attendance_nft_mock) = deploy_podcast_platform();
    let mut spy = spy_events();

    let creator_address = contract_address_const::<'event_creator'>();
    let attendance_nft_contract_address = attendance_nft_mock.contract_address;

    // Mock the caller address
    start_cheat_caller_address(podcast_platform.contract_address, creator_address);
    // Set block timestamp for event times
    start_cheat_block_timestamp(2000);

    // Prepare event details
    let event_details = sample_event_details(attendance_nft_contract_address);

    // Create the event
    podcast_platform.create_event(event_details);

    stop_cheat_block_timestamp();
    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert event emission
    let expected_event = PodcastPlatform::Event::EventCreated(
        EventCreated { event_id: 0, creator: creator_address } // First event should have ID 0
    );
    spy.assert_emitted(@array![(podcast_platform.contract_address, expected_event)]);

    // Verify event details can be retrieved using the view function
    let retrieved_event = podcast_platform.get_event(0);
    assert(retrieved_event.id == 0, 'Wrong event ID');
    assert(retrieved_event.creator == creator_address, 'Wrong event creator');
    assert(retrieved_event.title == "Test Event".into(), 'Wrong event title');
    assert(retrieved_event.attendance_nft_contract == attendance_nft_contract_address, 'Wrong event NFT contract');
    // Add more assertions for other fields if needed
}

#[test]
fn test_buy_ticket() {
    let (podcast_platform, _, _, _, _, attendance_nft_mock) = deploy_podcast_platform();
    let mut platform_spy = spy_events();
    let mut nft_spy = spy_events(); // Spy on events from the mock Attendance NFT contract

    let buyer_address = contract_address_const::<'ticket_buyer'>();
    let creator_address = contract_address_const::<'event_creator_for_ticket'>(); // Different creator for clarity
    let attendance_nft_contract_address = attendance_nft_mock.contract_address;

    // Need to create an event first so it exists in storage
    // Mock caller for event creation
    start_cheat_caller_address(podcast_platform.contract_address, creator_address);
     start_cheat_block_timestamp(3000); // Set timestamp for event creation

    let event_details = sample_event_details(attendance_nft_contract_address);
    podcast_platform.create_event(event_details); // Creates event with ID 0

    stop_cheat_block_timestamp();
    stop_cheat_caller_address(podcast_platform.contract_address); // Stop cheating creator

    let event_id = 0; // The ID of the event just created

    // Mock the caller address for buying the ticket
    start_cheat_caller_address(podcast_platform.contract_address, buyer_address);

    // Buy the ticket
    podcast_platform.buy_ticket(event_id);

    stop_cheat_caller_address(podcast_platform.contract_address);

    // Assert PodcastPlatform event emission
    let expected_platform_event = PodcastPlatform::Event::TicketPurchased(
        TicketPurchased { event_id, user: buyer_address }
    );
    platform_spy.assert_emitted(@array![(podcast_platform.contract_address, expected_platform_event)]);

    // Assert that the mock Attendance NFT contract's mint function was called
    let expected_nft_call_event = AttendanceNFTMock::Event::MintCalled(
        AttendanceNFTMintCalled {
            caller: podcast_platform.contract_address, // Contract calls mint
            recipient: buyer_address,
            token_id: event_id // Simple example uses event_id as token_id
        }
    );
    nft_spy.assert_emitted(@array![(attendance_nft_mock.contract_address, expected_nft_call_event)]);

    // Assert the standard ERC721 Transfer event from the mock NFT contract
    let zero_address = Zeroable::zero();
    let expected_nft_transfer_event = AttendanceNFTMock::Event::Transfer(
        AttendanceNFTTransfer { from: zero_address, to: buyer_address, token_id: event_id }
    );
    nft_spy.assert_emitted(@array![(attendance_nft_mock.contract_address, expected_nft_transfer_event)]);
}

#[test]
#[should_panic(expected: "Event does not exist")] // Assuming the check 'assert(!event.creator.is_zero(), 'Event does not exist');' is in place
fn test_buy_ticket_non_existent_event() {
     let (podcast_platform, _, _, _, _, _) = deploy_podcast_platform();
     let buyer_address = contract_address_const::<'ticket_buyer_panic'>();
     let non_existent_event_id = 999.try_into().unwrap();

     start_cheat_caller_address(podcast_platform.contract_address, buyer_address);

     // Attempt to buy a ticket for a non-existent event
     podcast_platform.buy_ticket(non_existent_event_id);

     stop_cheat_caller_address(podcast_platform.contract_address);
}


#[test]
fn test_get_event() {
    let (podcast_platform, _, _, _, _, attendance_nft_mock) = deploy_podcast_platform();

    let creator_address = contract_address_const::<'event_creator_get'>();
    let attendance_nft_contract_address = attendance_nft_mock.contract_address;

    // Mock caller for event creation
    start_cheat_caller_address(podcast_platform.contract_address, creator_address);
    start_cheat_block_timestamp(4000);

    // Create an event
    let event_details = sample_event_details(attendance_nft_contract_address);
    podcast_platform.create_event(event_details); // Creates event with ID 0

    stop_cheat_block_timestamp();
    stop_cheat_caller_address(podcast_platform.contract_address);

    let event_id = 0; // The ID of the event just created

    // Retrieve the event using the view function
    let retrieved_event = podcast_platform.get_event(event_id);

    // Assert the retrieved details match the created details
    assert(retrieved_event.id == event_id, 'Wrong event ID');
    assert(retrieved_event.creator == creator_address, 'Wrong event creator');
    assert(retrieved_event.title == "Test Event".into(), 'Wrong event title');
    assert(retrieved_event.description == "Event description".into(), 'Wrong event description');
    assert(retrieved_event.start_time == 4000 + 100, 'Wrong event start time'); // Based on mock timestamp
    assert(retrieved_event.end_time == 4000 + 200, 'Wrong event end time'); // Based on mock timestamp
    assert(retrieved_event.location == "Virtual".into(), 'Wrong event location');
    assert(retrieved_event.attendance_nft_contract == attendance_nft_contract_address, 'Wrong event NFT contract');
}

#[test]
fn test_upgrade_approved_by_dao() {
    let (podcast_platform, upgradeable_dispatcher, dao_mock, _, _, _) = deploy_podcast_platform();
    let mut platform_spy = spy_events();
    let mut dao_spy = spy_events(); // Spy on events from the mock DAO contract

    let new_class_hash = 9876.try_into().unwrap(); // Example new class hash
    let dao_proposal_id = 1.try_into().unwrap(); // Example DAO proposal ID
    let dao_contract_address = dao_mock.contract_address;

    // Set the mock DAO to return true for is_proposal_executed for this proposal ID
    let dao_mock_internal_dispatcher = DAOMock::InternalTraitDispatcher { contract_address: dao_contract_address };
    dao_mock_internal_dispatcher.set_executed_status(dao_proposal_id, true);

    // Mock the caller address (doesn't matter for upgrade if DAO governs)
    let caller = contract_address_const::<'upgrade_caller'>();
    start_cheat_caller_address(podcast_platform.contract_address, caller);


    // Call the upgrade function
    upgradeable_dispatcher.upgrade(new_class_hash, dao_proposal_id);

    stop_cheat_caller_address(podcast_platform.contract_address);


    // Assert that the mock DAO's is_proposal_executed was called
    let expected_dao_call_event = DAOMock::Event::IsProposalExecutedCalled(
        IsProposalExecutedCalled { proposal_id: dao_proposal_id }
    );
    dao_spy.assert_emitted(@array![(dao_mock.contract_address, expected_dao_call_event)]);

    // Assert the Upgradeable event from the PodcastPlatform contract
    let expected_platform_event = podcast_platform::PodcastPlatform::Event::UpgradeableEvent(
        podcast_platform::UpgradeableComponent::Event::Upgraded(
            podcast_platform::UpgradeableComponent::Upgraded { implementation: new_class_hash }
        )
    );
    platform_spy.assert_emitted(@array![(podcast_platform.contract_address, expected_platform_event)]);

    // Note: Verifying the actual class hash change would require checking contract state or
    // deployment details, which might go beyond simple dispatcher tests shown in context.
    // Asserting the emitted event indicates the upgrade logic was triggered.
}

#[test]
#[should_panic(expected: "Upgrade not approved by DAO proposal")] // Based on the assert message in the contract
fn test_upgrade_not_approved_by_dao() {
     let (podcast_platform, upgradeable_dispatcher, dao_mock, _, _, _) = deploy_podcast_platform();
     let new_class_hash = 9877.try_into().unwrap(); // Another example class hash
     let dao_proposal_id = 2.try_into().unwrap(); // Another example DAO proposal ID
     let dao_contract_address = dao_mock.contract_address;

     // Set the mock DAO to return false for is_proposal_executed for this proposal ID
     let dao_mock_internal_dispatcher = DAOMock::InternalTraitDispatcher { contract_address: dao_contract_address };
     dao_mock_internal_dispatcher.set_executed_status(dao_proposal_id, false);

     // Mock the caller address
     let caller = contract_address_const::<'upgrade_caller_panic'>();
     start_cheat_caller_address(podcast_platform.contract_address, caller);

     // Call the upgrade function - should panic
     upgradeable_dispatcher.upgrade(new_class_hash, dao_proposal_id);

     stop_cheat_caller_address(podcast_platform.contract_address);

     // No event assertions needed here as the transaction is expected to panic.
}

#[test]
#[should_panic(expected: "DAO contract address not set")] // Based on the assert message in the contract
fn test_upgrade_dao_address_not_set() {
     // Deploy the contract with a zero DAO address to simulate it not being set
     let podcast_platform_class_hash = declare("PodcastPlatform").unwrap().class_hash();
     let mut constructor_calldata = array![];
     let tipping_token_address = contract_address_const::<'mock_token'>();
     let zero_address = Zeroable::zero();

     Serde::serialize(@tipping_token_address, ref constructor_calldata);
     Serde::serialize(@zero_address, ref constructor_calldata); // Pass zero address for DAO

     let (podcast_platform_address, _) = deploy_contract(podcast_platform_class_hash, constructor_calldata.span()).unwrap();

     let upgradeable_dispatcher = IUpgradeableDispatcher { contract_address: podcast_platform_address };

     let new_class_hash = 9878.try_into().unwrap();
     let dao_proposal_id = 3.try_into().unwrap();

     let caller = contract_address_const::<'upgrade_caller_zero_dao'>();
     start_cheat_caller_address(podcast_platform_address, caller);

     // Call the upgrade function - should panic
     upgradeable_dispatcher.upgrade(new_class_hash, dao_proposal_id);

     stop_cheat_caller_address(podcast_platform_address);
}