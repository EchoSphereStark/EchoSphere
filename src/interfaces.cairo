use starknet::{
    ContractAddress, get_caller_address, ClassHash, contract_address_const,
    storage::{
        Map, StorageMapWriteAccess, StorageMapReadAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, StoragePathEntry, MutableVecTrait, Vec, VecTrait
    }
};

#[starknet::interface]
pub trait IUserRegistry {
    fn set_is_creator(ref self: ContractState, is_creator: bool);
    fn is_creator(self: @ContractState, user: ContractAddress) -> bool;
    fn favorite_episode(ref self: ContractState, episode_id: u256);
    fn unfavorite_episode(ref self: ContractState, episode_id: u256);
    fn follow_creator(ref self: ContractState, creator: ContractAddress);
    fn unfollow_creator(ref self: ContractState, creator: ContractAddress);
    fn is_favorite(self: @ContractState, user: ContractAddress, episode_id: u256) -> bool;
    fn is_following(self: @ContractState, user: ContractAddress, creator: ContractAddress) -> bool;
    fn tip_creator(ref self: ContractState, creator: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IPodcast {
    fn create_podcast(ref self: ContractState, name: ByteArray, description: ByteArray) -> u256;
    fn add_episode(ref self: ContractState, podcast_id: u256, title: ByteArray, description: ByteArray, uri: ByteArray, access_condition: Option<AccessCondition>) -> u256;
    fn has_access(self: @ContractState, user: ContractAddress, episode_id: u256) -> bool;
    fn get_podcast(self: @ContractState, podcast_id: u256) -> Option<Podcast>;
    fn get_episode(self: @ContractState, episode_id: u256) -> Option<Episode>;
    fn get_podcast_episode_count(self: @ContractState, podcast_id: u256) -> u256;
    fn get_podcast_episode(self: @ContractState, podcast_id: u256, index: u256) -> Option<u256>;
    fn get_owner_podcast_count(self: @ContractState, owner: ContractAddress) -> u256;
    fn get_owner_podcast(self: @ContractState, owner: ContractAddress, index: u256) -> Option<u256>;
}