import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/location_service.dart';
import '../../lib/services/vinculo_familiar_service.dart';
import '../../lib/services/notification_service.dart';
import '../../lib/services/offline_cache_service.dart';
import '../../lib/services/organizacao_service.dart';
import '../../lib/services/supabase_service.dart';

// Gerar mocks usando mockito
@GenerateMocks([
  SupabaseClient,
  SharedPreferences,
  LocationService,
  VinculoFamiliarService,
  NotificationService,
  OfflineCacheService,
  OrganizacaoService,
  SupabaseService,
  FunctionsClient,
])
void main() {}

