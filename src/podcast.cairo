

struct Episode {
    id: felt,
    metadata: ContentMetadata,
    creator_id: felt,
    publish_date: felt,
    views: felt,
}

struct ContentMetadata {
    title: felt,
    description: felt,
    tags: felt,
    episode_number: felt,
    categories: felt,
}

struct Playlist {
    id: u128,
    title: ByteArray,
    description: ByteArray,
    episodes: Array<Episode>, 
}

struct UserProfile {
    name: felt,
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

