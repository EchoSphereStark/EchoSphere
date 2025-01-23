# Declare the namespace for the interfaces
namespace echosphere.interfaces;

# Interface for user profile management
@contract_interface
namespace IUserProfile {
    func create_profile(user_id: felt, username: felt, description: felt) -> ();
    func update_profile(user_id: felt, new_username: felt, new_description: felt) -> ();
    func get_profile(user_id: felt) -> (username: felt, description: felt);
}

# Interface for video management
@contract_interface
namespace IVideoManagement {
    func upload_video(user_id: felt, video_id: felt, video_data: felt) -> ();
    func update_video(video_id: felt, new_video_data: felt) -> ();
    func delete_video(video_id: felt) -> ();
    func get_video(video_id: felt) -> (video_data: felt);
}

# Interface for community interactions
@contract_interface
namespace ICommunityInteraction {
    func post_comment(video_id: felt, user_id: felt, comment_text: felt) -> ();
    func like_video(video_id: felt, user_id: felt) -> ();
    func share_video(video_id: felt, user_id: felt) -> ();
}