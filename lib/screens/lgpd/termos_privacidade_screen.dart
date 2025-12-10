import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';

/// Tela de Termos de Uso e Política de Privacidade (LGPD)
class TermosPrivacidadeScreen extends StatelessWidget {
  final bool showTerms;

  const TermosPrivacidadeScreen({
    super.key,
    this.showTerms = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  showTerms ? 'Termos de Uso' : 'Política de Privacidade',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFA8B8FF),
                        Color(0xFF9B7EFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Conteúdo
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showTerms
                            ? 'Termos de Uso - CareMind'
                            : 'Política de Privacidade - CareMind',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Última atualização: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._buildContent(showTerms),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(bool isTerms) {
    if (isTerms) {
      return [
        _buildSection(
          title: '1. Aceitação dos Termos',
          content:
              'Ao utilizar o aplicativo CareMind, você concorda com estes Termos de Uso. '
              'Se não concordar, não utilize o aplicativo.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '2. Uso do Aplicativo',
          content:
              'O CareMind é um aplicativo de assistência à rotina e medicação. '
              'O uso é destinado exclusivamente para fins de organização pessoal e familiar.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '3. Responsabilidades',
          content:
              'Você é responsável por manter a confidencialidade de suas credenciais de acesso. '
              'Informações sobre medicamentos são meramente informativas e não substituem orientação médica profissional.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '4. Dados Sensíveis',
          content:
              'Dados de saúde são tratados conforme a Lei Geral de Proteção de Dados (LGPD) e nossa Política de Privacidade.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '5. Modificações',
          content:
              'Reservamo-nos o direito de modificar estes termos a qualquer momento. '
              'Alterações serão comunicadas através do aplicativo.',
        ),
      ];
    } else {
      return [
        _buildSection(
          title: '1. Coleta de Dados',
          content:
              'Coletamos apenas os dados necessários para o funcionamento do aplicativo: '
              'nome, e-mail, informações de medicamentos e compromissos cadastrados por você.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '2. Dados Sensíveis de Saúde',
          content:
              'Dados relacionados a medicamentos e compromissos médicos são considerados dados sensíveis pela LGPD. '
              'Utilizamos apenas para fornecer as funcionalidades do aplicativo.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '3. Compartilhamento com Familiares',
          content:
              'Quando você cria um vínculo familiar, os dados podem ser compartilhados com o familiar vinculado, '
              'conforme seu consentimento explícito. Você pode revogar este consentimento a qualquer momento.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '4. Uso de Dados para Inteligência e Pesquisa (Anonimização)',
          content:
              'O Caremind poderá utilizar, compartilhar ou comercializar dados agregados e anonimizados com parceiros comerciais, '
              'instituições de pesquisa e indústria farmacêutica para fins de estatística, melhoria de tratamentos de saúde e análise de mercado.\n\n'
              'Importante: Esses dados passam por um processo rigoroso de anonimização, o que torna impossível a identificação pessoal do usuário. '
              'Em nenhuma hipótese venderemos dados que identifiquem você individualmente (como seu nome, CPF ou endereço) sem seu consentimento expresso e específico, '
              'em conformidade com o Art. 11 da Lei Geral de Proteção de Dados (LGPD).',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '5. Segurança dos Dados',
          content:
              'Implementamos medidas técnicas e organizacionais adequadas para proteger seus dados contra acesso não autorizado, '
              'perda ou destruição.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '6. Seus Direitos (LGPD)',
          content:
              'Você tem direito a: acessar seus dados, corrigi-los, solicitar exclusão (direito ao esquecimento), '
              'exportar seus dados e revogar consentimentos.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '7. Exportação e Exclusão',
          content:
              'No menu de perfil, você pode exportar todos os seus dados em formato JSON ou solicitar a exclusão completa da conta.',
        ),
        const SizedBox(height: 20),
        _buildSection(
          title: '8. Contato',
          content:
              'Para exercer seus direitos ou esclarecer dúvidas, entre em contato através do aplicativo ou pelo e-mail: '
              'privacidade@caremind.online',
        ),
      ];
    }
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.leagueSpartan(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppTextStyles.leagueSpartan(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

