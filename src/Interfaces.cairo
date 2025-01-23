use starknet::ContractAddress;

//  Interface for user profile management
#[starknet::interface]
pub trait IUserProfile<TContractState> {
    fn create_profile() -> ();
    fn update_profile() -> ();
    fn get_profile();
}

//  Interface for video management
#[starknet::interface]
pub trait IVideoManagement<TContractState> {
    fn upload_video() -> ();
    fn update_video(video_id: felt, new_video_data: felt) -> ();
    fn delete_video(video_id: felt) -> ();
    fn get_video(video_id: felt) -> (video_data: felt);
}

// Interface for community interactions
#[starknet::interface]
pub trait ICommunityInteraction<TContractState> {
    fn post_comment(video_id: felt, ) -> ();
    fn like_video(video_id: felt, user_id: felt) -> ();
    fn share_video(video_id: felt, user_id: felt) -> ();
}