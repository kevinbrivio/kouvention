const Duration kProfileStalenessWindow = Duration(minutes: 5);

/// Firestore `whereIn` hard limit.
const int kProfileWhereInChunkSize = 30;

const int kProfileMaxCached = 500;
