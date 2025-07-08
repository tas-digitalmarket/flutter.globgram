import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/p2p_manager.dart';

// Test BLoC to isolate import issue
class TestBloc extends Bloc<String, String> {
  final P2PManager _manager = P2PManager();

  TestBloc() : super('initial');
}
