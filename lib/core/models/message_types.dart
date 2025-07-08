import 'package:hive/hive.dart';

part 'message_types.g.dart';

@HiveType(typeId: 1)
enum MessageType { 
  @HiveField(0)
  text, 
  @HiveField(1)
  voice 
}
