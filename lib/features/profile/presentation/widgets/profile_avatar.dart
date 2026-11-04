import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({this.url, this.radius = 20, super.key});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Icon(
        Icons.person_rounded,
        size: radius * 1.2,
        color: AppColors.primary,
      ),
    );
  }
}
