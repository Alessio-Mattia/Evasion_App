/// A position on Earth, in degrees: latitude from -90 to 90, longitude from
/// -180 to 180.
///
/// Shared by the features that place things on the map, such as posts, and
/// by the location service that will give the phone's position.
typedef GeoPoint = ({double latitude, double longitude});

/// A rectangle on the map, such as the area shown on screen: its south-west
/// and north-east corners.
typedef GeoBounds = ({GeoPoint southWest, GeoPoint northEast});
