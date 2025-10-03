@echo off

REM Criar diretórios se não existirem
if not exist "lib\screens\auth" mkdir "lib\screens\auth"
if not exist "lib\screens\individual" mkdir "lib\screens\individual"
if not exist "lib\screens\familiar" mkdir "lib\screens\familiar"
if not exist "lib\screens\shared" mkdir "lib\screens\shared"
if not exist "lib\screens\medication" mkdir "lib\screens\medication"
if not exist "lib\screens\family" mkdir "lib\screens\family"
if not exist "lib\screens\utils" mkdir "lib\screens\utils"

REM Mover arquivos para auth
move /Y "lib\screens\auth_screen.dart" "lib\screens\auth\"
move /Y "lib\screens\welcome_screen.dart" "lib\screens\auth\"

REM Mover arquivos para individual
move /Y "lib\screens\individual_dashboard_screen_fixed.dart" "lib\screens\individual\dashboard_screen.dart"
move /Y "lib\screens\rotina_screen.dart" "lib\screens\individual\"

REM Mover arquivos para familiar
move /Y "lib\screens\familiar_dashboard_screen.dart" "lib\screens\familiar\dashboard_screen.dart"
move /Y "lib\screens\metricas_screen.dart" "lib\screens\familiar\"

REM Mover arquivos para medication
move /Y "lib\screens\add_edit_medicamento_form.dart" "lib\screens\medication\"
move /Y "lib\screens\gestao_medicamentos_screen.dart" "lib\screens\medication\"

REM Mover arquivos para family
move /Y "lib\screens\exibir_convite_screen.dart" "lib\screens\family\"
move /Y "lib\screens\familiares_screen.dart" "lib\screens\family\"
move /Y "lib\screens\family_role_selection_screen.dart" "lib\screens\family\"
move /Y "lib\screens\link_account_screen.dart" "lib\screens\family\"
move /Y "lib\screens\link_account_screen_new.dart" "lib\screens\family\"

REM Mover arquivos para shared
move /Y "lib\screens\alertas_screen.dart" "lib\screens\shared\"
move /Y "lib\screens\perfil_screen.dart" "lib\screens\shared\"
move /Y "lib\screens\main_navigator_screen.dart" "lib\screens\shared\"

REM Mover arquivos para utils
move /Y "lib\screens\qr_scanner_screen.dart" "lib\screens\utils\"

REM Remover arquivos antigos/depreciados
del "lib\screens\individual_dashboard_screen.dart"

echo Estrutura de pastas organizada com sucesso!
pause
