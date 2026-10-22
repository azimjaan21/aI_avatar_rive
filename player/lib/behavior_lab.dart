import 'package:flutter/material.dart';
import 'avatar_controller.dart';

/// Additional test controls inside the existing sidebar; no page redesign.
class AvatarBehaviorLab extends StatelessWidget {
  const AvatarBehaviorLab({super.key, required this.avatar});
  final AvatarController avatar;
  static const labels = {
    AvatarEmotion.neutral: 'Neutral',
    AvatarEmotion.smile: 'Smile',
    AvatarEmotion.happy: 'Happy',
    AvatarEmotion.encouraging: 'Encouraging',
    AvatarEmotion.softLaugh: 'Soft laugh',
  };
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('behavior-lab'),
    tilePadding: EdgeInsets.zero,
    title: const Text(
      'Behavior lab',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${avatar.conversation.name} · ${avatar.mode == AvatarAudioMode.offline ? 'Offline timeline' : 'Local PCM stream'}',
      style: const TextStyle(fontSize: 12),
    ),
    childrenPadding: const EdgeInsets.only(bottom: 12),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Audio mode'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final mode in [
            AvatarAudioMode.offline,
            AvatarAudioMode.localStream,
          ])
            ChoiceChip(
              key: Key('mode-${mode.name}'),
              label: Text(
                mode == AvatarAudioMode.offline
                    ? 'Offline timeline'
                    : 'Local streaming simulation',
              ),
              selected: avatar.mode == mode,
              onSelected: avatar.ready
                  ? (_) => avatar.setAudioMode(mode)
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        avatar.alignmentStatus,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 16),
      const Text('Expression'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final emotion in AvatarEmotion.values)
            ChoiceChip(
              key: Key('emotion-${emotion.name}'),
              label: Text(labels[emotion]!),
              selected: avatar.emotion == emotion,
              onSelected: avatar.ready
                  ? (_) => avatar.setEmotion(emotion)
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Conversation state'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final state in [
            ConversationState.idle,
            ConversationState.listening,
            ConversationState.thinking,
            ConversationState.speaking,
          ])
            ActionChip(
              key: Key('state-${state.name}'),
              label: Text(state.name),
              onPressed: !avatar.ready
                  ? null
                  : () {
                      switch (state) {
                        case ConversationState.idle:
                          avatar.onIdle();
                        case ConversationState.listening:
                          avatar.onListening();
                        case ConversationState.thinking:
                          avatar.onThinking();
                        case ConversationState.speaking:
                          avatar.onSpeaking();
                        default:
                          break;
                      }
                    },
            ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            key: const Key('speech-interrupt'),
            onPressed: avatar.ready ? avatar.onSpeechInterrupted : null,
            child: const Text('Interrupt'),
          ),
          TextButton(
            key: const Key('speech-stop'),
            onPressed: avatar.ready ? avatar.stop : null,
            child: const Text('Stop / reset'),
          ),
        ],
      ),
      if (avatar.isStreaming)
        Text(
          'Buffered ${(avatar.stream.queuedSeconds * 1000).round()} ms · Start ${avatar.stream.firstPlaybackMs?.round() ?? 0} ms',
          key: const Key('stream-metrics'),
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
    ],
  );
}
