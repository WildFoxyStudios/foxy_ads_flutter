import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
