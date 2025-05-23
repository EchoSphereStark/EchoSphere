#[starknet::contract]

pub mod users {
    use UpgradeableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{UpgradeableComponent, interface::IUpgradeable};
    use crate::interfaces::IUserRegistry;
    use openzeppelin::token::erc20::interface::IERC20;

    use starknet::{
        get_caller_address, ContractAddress, ClassHash, get_block_timestamp,
        storage::{Map, StoragePointerWriteAccess, StoragePathEntry, MutableVecTrait, Vec, VecTrait}
    };

component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

#[abi(embed_v0)]
impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

#[storage]
struct Storage {
    #[substorage(v0)]
    ownable: OwnableComponent::Storage,
    #[substorage(v0)]
    upgradeable: UpgradeableComponent::Storage,
    tipping_token: ContractAddress,
}

#[derive(Copy, Drop)]
struct Episode {
    id: u256,
    metadata: ContentMetadata,
    creator: ContractAddress,
    publish_date: u256,
    views: u256,
}

#[derive(Copy, Drop)]
struct ContentMetadata {
    title: ByteArray,
    description: ByteArray,
    tags: Vec<ByteArray>,
    episode_number: u256,
    categories: Vec<ByteArray>,
}

#[derive(Copy, Drop)]
struct Playlist {
    id: u128,
    title: ByteArray,
    description: ByteArray,
    episodes: Vec<Episode>, 
}

#[derive(Copy, Drop)]
struct UserProfile {
    name: ByterArray,
    bio: ByteArray,
    profile_photo: ByteArray,
    banner_image: ByteArray,
    social_links: ByteArray,
    playlists: Vec<Playlist> 
}


#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    #[flat]
    OwnableEvent: OwnableComponent::Event,
    #[flat]
    UpgradeableEvent: UpgradeableComponent::Event,
    CreatorSet: (ContractAddress, bool),
    FavoriteAdded: (ContractAddress, u256),
    FavoriteRemoved: (ContractAddress, u256),
    FollowAdded: (ContractAddress, ContractAddress),
    FollowRemoved: (ContractAddress, ContractAddress),
    TipSent: (ContractAddress, ContractAddress, u256),
}

#[constructor]
fn constructor(ref self: ContractState, tipping_token: ContractAddress) {
    self.tipping_token.write(tipping_token);
}

#[abi(embed_v0)]
impl UserRegistryImpl of super::IUserRegistry {
    use crate::interfaces::IUserRegistry;

    fn set_is_creator(ref self: ContractState, is_creator: bool) {
        let caller = starknet::get_caller_address();
        self.users.write(caller, is_creator);
        self.emit(Event::CreatorSet((caller, is_creator)));
    }

    fn is_creator(self: @ContractState, user: ContractAddress) -> bool {
        self.users.read(user)
    }

    fn favorite_episode(ref self: ContractState, episode_id: u256) {
        let caller = starknet::get_caller_address();
        self.favorites.write((caller, episode_id), true);
        self.emit(Event::FavoriteAdded((caller, episode_id)));
    }

    fn unfavorite_episode(ref self: ContractState, episode_id: u256) {
        let caller = starknet::get_caller_address();
        self.favorites.write((caller, episode_id), false);
        self.emit(Event::FavoriteRemoved((caller, episode_id)));
    }

    // fn follow_creator(ref self: ContractState, creator: ContractAddress) {
    //     let caller = starknet::get_caller_address();
    //     self.follows.write((caller, creator), true);
    //     self.emit(Event::FollowAdded((caller, creator)));
    // }

    // fn unfollow_creator(ref self: ContractState, creator: ContractAddress) {
    //     let caller = starknet::get_caller_address();
    //     self.follows.write((caller, creator), false);
    //     self.emit(Event::FollowRemoved((caller, creator)));
    //     }

    // fn is_favorite(self: @ContractState, user: ContractAddress, episode_id: u256) -> bool {
    //     self.favorites.read((user, episode_id))
    //  }

    // fn is_following(self: @ContractState, user: ContractAddress, creator: ContractAddress) -> bool {
    //     self.follows.read((user, creator))
    // }

    // fn tip_creator(ref self: ContractState, creator: ContractAddress, amount: u256) {
    //     let caller = starknet::get_caller_address();
    //     let token = IERC20Dispatcher { contract_address: self.tipping_token.read() };
    //     token.transfer_from(caller, creator, amount);
    //     self.emit(Event::TipSent((caller, creator, amount)));
    // }
}


#[abi(embed_v0)]
impl UpgradeableImpl of IUpgradeable<ContractState> {
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        self.ownable.assert_only_owner();
        self.upgradeable.upgrade(new_class_hash);
    }
}
}