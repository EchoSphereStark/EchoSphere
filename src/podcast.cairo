
#[starknet::contract]
use UpgradeableComponent::InternalTrait;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::upgrades::{UpgradeableComponent, interface::IUpgradeable};
use starknet::{
    get_caller_address, ContractAddress, ClassHash, get_block_timestamp,
    storage::{Map, StoragePointerWriteAccess, StoragePathEntry},
};

struct Episode {
    id: u256,
    metadata: ContentMetadata,
    creator_id: u256,
    publish_date: u256,
    views: u256,
}

struct ContentMetadata {
    title: ByteArray,
    description: ByteArray,
    tags: ByteArray,
    episode_number: u256,
    categories: ByteArray,
}

struct Playlist {
    id: u128,
    title: ByteArray,
    description: ByteArray,
    episodes: Array<Episode>, 
}

struct UserProfile {
    name: ByterArray,
    bio: ByteArray,
    profile_photo: ByteArray,
    banner_image: ByteArray,
    social_links: ByteArray,
    playlists: Array<Playlist> 
}

@interface PodcastInterface {
    func create_user_profile(name: felt, bio: felt, profile_photo: felt, banner_image: felt, social_links: felt) -> felt;
    func get_user_profile(user_id: felt) -> UserProfile;
    
    
    
    
    func get_episode_analytics(episode_id: felt) -> (felt, felt);
    func create_playlist(title: felt, description: felt, episodes: Array<Episode>) -> felt;
    func get_user_playlists(user_id: felt) -> Array<Playlist>;
    func get_playlist(user_id: felt) -> Array<Playlist>;
}

