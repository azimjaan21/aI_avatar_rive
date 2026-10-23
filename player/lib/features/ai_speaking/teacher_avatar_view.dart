import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import '../../avatar_controller.dart';

/// Reusable rendering surface. The classroom stays outside the moving rig.
class TeacherAvatarView extends StatelessWidget {
  const TeacherAvatarView({
    super.key,
    required this.controller,
    this.cover = false,
  });
  final AvatarController controller;
  final bool cover;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(controller.profile.backgroundAsset, fit: BoxFit.cover),
      if (controller.riveController != null)
        LayoutBuilder(
          builder: (context, constraints) {
            // A portrait cover crop would cut the face off in landscape.
            final useCover =
                cover && constraints.maxHeight >= constraints.maxWidth;
            controller.configureViewport(
              constraints.maxWidth,
              constraints.maxHeight,
              cover: useCover,
            );
            return rive.RiveWidget(
              key: const Key('teacher-avatar'),
              controller: controller.riveController!,
              fit: useCover ? rive.Fit.cover : rive.Fit.contain,
              alignment: cover ? Alignment.center : Alignment.bottomCenter,
            );
          },
        )
      else
        Center(
          child: controller.error == null
              ? const CircularProgressIndicator()
              : const Icon(Icons.error_outline),
        ),
    ],
  );
}
