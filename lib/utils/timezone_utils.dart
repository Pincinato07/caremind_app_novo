import 'package:timezone/timezone.dart' as tz;
import '../core/utils/app_logger.dart';


/// Utilitários para manipulação de timezone
class TimezoneUtils {
  /// Obtém o timezone IANA do dispositivo atual
  /// Retorna: 'America/Sao_Paulo' como fallback se não conseguir detectar
  static String getCurrentTimezone() {
    try {
      // Tenta obter o timezone do sistema
      final timeZoneName = DateTime.now().timeZoneName;
      
      // Mapeia abreviações comuns para IANA
      final Map<String, String> abbreviationMap = {
        'BRST': 'America/Sao_Paulo',
        'BRT': 'America/Sao_Paulo',
        'AMT': 'America/Manaus',
        'AMST': 'America/Campo_Grande',
        'FNT': 'America/Noronha',
        'America/Sao_Paulo': 'America/Sao_Paulo',
        'America/Manaus': 'America/Manaus',
        'America/Campo_Grande': 'America/Campo_Grande',
        'America/Rio_Branco': 'America/Rio_Branco',
        'America/Fortaleza': 'America/Fortaleza',
        'America/Recife': 'America/Recife',
        'America/Bahia': 'America/Bahia',
        'America/Belem': 'America/Belem',
        'America/Araguaina': 'America/Araguaina',
        'America/Maceio': 'America/Maceio',
        'America/Noronha': 'America/Noronha',
      };

      // Se já é um IANA válido, retorna
      if (abbreviationMap.containsKey(timeZoneName) && 
          timeZoneName.contains('/')) {
        return timeZoneName;
      }

      // Tenta mapear abreviação
      final mapped = abbreviationMap[timeZoneName];
      if (mapped != null) {
        return mapped;
      }

      // Fallback: tenta usar o offset para determinar
      final offset = DateTime.now().timeZoneOffset;
      final offsetHours = offset.inHours;
      
      // Mapeia offsets principais do Brasil
      if (offsetHours == -3) return 'America/Sao_Paulo';
      if (offsetHours == -4) return 'America/Manaus';
      if (offsetHours == -5) return 'America/Rio_Branco';

      // Último fallback
      return 'America/Sao_Paulo';
    } catch (e) {
      AppLogger.error('Erro ao detectar timezone: $e');
      return 'America/Sao_Paulo';
    }
  }

  /// Verifica se o timezone é válido para o Brasil
  static bool isValidBrazilianTimezone(String timezone) {
    final validTimezones = [
      'America/Sao_Paulo',
      'America/Manaus',
      'America/Campo_Grande',
      'America/Rio_Branco',
      'America/Fortaleza',
      'America/Recife',
      'America/Bahia',
      'America/Belem',
      'America/Araguaina',
      'America/Maceio',
      'America/Noronha',
    ];
    return validTimezones.contains(timezone);
  }

  /// Obtém o offset em horas para um timezone específico
  static int getTimezoneOffsetHours(String timezone) {
    try {
      final location = tz.getLocation(timezone);
      final now = tz.TZDateTime.now(location);
      return now.timeZoneOffset.inHours;
    } catch (e) {
      // Fallback para America/Sao_Paulo
      return -3;
    }
  }

  /// Formata o timezone para exibição
  static String formatTimezoneLabel(String timezone) {
    final Map<String, String> labels = {
      'America/Sao_Paulo': 'Brasília (UTC-3)',
      'America/Manaus': 'Manaus (UTC-4)',
      'America/Campo_Grande': 'Campo Grande (UTC-4)',
      'America/Rio_Branco': 'Rio Branco (UTC-5)',
      'America/Fortaleza': 'Fortaleza (UTC-3)',
      'America/Recife': 'Recife (UTC-3)',
      'America/Bahia': 'Bahia (UTC-3)',
      'America/Belem': 'Belém (UTC-3)',
      'America/Araguaina': 'Araguaína (UTC-3)',
      'America/Maceio': 'Maceió (UTC-3)',
      'America/Noronha': 'Fernando de Noronha (UTC-2)',
    };
    return labels[timezone] ?? timezone;
  }

  /// Converte um horário local para UTC baseado no timezone
  static DateTime localToUTC(String timezone, DateTime localTime) {
    try {
      final location = tz.getLocation(timezone);
      final tzDateTime = tz.TZDateTime(
        location,
        localTime.year,
        localTime.month,
        localTime.day,
        localTime.hour,
        localTime.minute,
        localTime.second,
      );
      return tzDateTime.toUtc();
    } catch (e) {
      // Fallback simples
      return localTime.toUtc();
    }
  }

  /// Converte um horário UTC para local baseado no timezone
  static DateTime utcToLocal(String timezone, DateTime utcTime) {
    try {
      final location = tz.getLocation(timezone);
      final tzDateTime = tz.TZDateTime.from(utcTime, location);
      return tzDateTime;
    } catch (e) {
      // Fallback simples
      return utcTime;
    }
  }
}

