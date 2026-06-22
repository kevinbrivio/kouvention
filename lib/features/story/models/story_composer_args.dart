enum StoryCreationMode { video, photo, text, voice }

class StoryComposerArgs {
  const StoryComposerArgs({required this.initialMode});

  final StoryCreationMode initialMode;
}

const storyLifetime = Duration(minutes: 1);

bool isValidTextStory(String text) => text.trim().isNotEmpty;

DateTime storyExpiryFrom(DateTime createdAt) => createdAt.add(storyLifetime);
