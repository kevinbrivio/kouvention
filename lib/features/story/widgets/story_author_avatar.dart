import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kouvention/cores/constants/tokens.dart';

class StoryAuthorAvatar extends StatelessWidget {
  const StoryAuthorAvatar({
    super.key,
    required this.authorUid,
    required this.authorName,
    required this.photoUrl,
    required this.diameter,
  });

  final String authorUid;
  final String authorName;
  final String? photoUrl;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final validPhotoUrl = photoUrl?.trim();

    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: validPhotoUrl != null && validPhotoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: validPhotoUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => _initial(),
                errorWidget: (_, _, _) => _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() {
    final backgroundColor = AppColorTokens.senderNameColor(authorUid);
    final foregroundColor = backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    final trimmedName = authorName.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: foregroundColor,
            fontSize: diameter * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
