import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'features/dashboard/sidebar.dart'
    show
        SidebarDrawer,
        ThemeToggleProvider,
        resetarSelecaoSidebar,
        selecionarItemSidebar;
import 'features/modals/alertas_modal.dart' show AlertasScreen;
import 'features/modals/ocorrencias_modal.dart' show OcorrenciasScreen;
import 'features/modals/ramais_modal.dart' show RamaisPanel;
import 'features/modals/chaves_modal.dart' show ChavesModal;
import 'features/modals/turnos_modal.dart' show TurnosScreen;
import 'features/modals/condominio_modal.dart' show CondominioPanel;
import 'features/modals/ajustes_modal.dart' show AjustesModal;
import 'features/modals/novidades_modal.dart' show NovidadesModal;
import 'features/modals/cameras_modal.dart'
    show showCamerasModal, isCamerasView, CamerasModal;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'features/dashboard/dashboard_panels.dart'
    show EncomendasPanel, VisitantesPanel, UnidadesPanel, VagasPanel;

import 'features/dashboard/dashboard.dart' show DashboardScreen;
import 'features/auth/login.dart';
import 'core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/crypto_utils.dart';
import 'core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'features/bootstrap/bootstrap_page.dart';
import 'core/config/app_version.dart';

//-----------------------------//
// SISTEMA DE PÁGINAS LATERAIS
//-----------------------------//

// Widget para gerenciar páginas laterais abertas
class SidePanelManager extends StatefulWidget {
  final Widget child;
  final Map<String, Widget> activePanels;
  final VoidCallback? onClosePanel;

  const SidePanelManager({
    super.key,
    required this.child,
    required this.activePanels,
    this.onClosePanel,
  });

  @override
  State<SidePanelManager> createState() => _SidePanelManagerState();
}

class _SidePanelManagerState extends State<SidePanelManager>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _controllers = {};

  @override
  void didUpdateWidget(SidePanelManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Adicionar novos painéis
    for (final key in widget.activePanels.keys) {
      if (!_controllers.containsKey(key)) {
        _controllers[key] = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        )..forward();
      }
    }

    // Remover painéis fechados
    for (final key in _controllers.keys.toList()) {
      if (!widget.activePanels.containsKey(key)) {
        _controllers[key]?.dispose();
        _controllers.remove(key);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Conteúdo principal
        widget.child,

        // Painéis laterais
        ...widget.activePanels.entries.map((entry) {
          final key = entry.key;
          final panel = entry.value;
          final controller = _controllers[key];

          if (controller == null) return const SizedBox.shrink();

          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _getPanelWidth(context),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: controller,
                    curve: Curves.easeOut,
                  )),
                  child: Material(
                    elevation: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(-4, 0),
                          ),
                        ],
                      ),
                      child: panel,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  double _getPanelWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Margem dinâmica da sidebar (calculada como no sidebar.dart)
    final double sidebarMargin = (screenWidth * 0.018).clamp(8.0, 20.0);
    final double sidebarRightBoundary = sidebarMargin + 70.0 + 10.0;

    double panelWidth;
    if (screenWidth < 768) {
      panelWidth = screenWidth * 0.9;
    } else if (screenWidth < 1200) {
      panelWidth = screenWidth * 0.6;
    } else {
      panelWidth = screenWidth * 0.48;
    }

    // Ajuste para não sobrepor a sidebar
    double leftPos = screenWidth - panelWidth;
    if (leftPos < sidebarRightBoundary && screenWidth < 1440) {
      panelWidth = screenWidth - sidebarRightBoundary - 10;
    }

    return panelWidth;
  }
}

// Widget base para páginas laterais
abstract class SidePanel extends StatefulWidget {
  final VoidCallback onClose;

  const SidePanel({super.key, required this.onClose});

  String get panelKey;

  @override
  State<SidePanel> createState();
}

// Instância global para controle de painéis laterais
late _MyAppState? _globalAppState;

//-----------------------------//
// FIM DO SISTEMA DE PÁGINAS LATERAIS
//-----------------------------//

Future<void> _autoUpdateIfNeeded() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('app_version');
    if (cached == null) {
      await prefs.setString('app_version', appVersion);
      return;
    }
    if (cached != appVersion) {
      await prefs.setString('app_version', appVersion);
      if (kIsWeb) {
        final cacheNames = await html.window.caches?.keys();
        if (cacheNames != null) {
          await Future.wait(
            cacheNames.map((name) => html.window.caches!.delete(name)),
          );
        }
        html.window.location.reload();
      }
    }
  } catch (_) {}
}

/// URL original salva antes do Flutter modificar
String? originalUrl;

void main() async {
  // Salvar URL original ANTES de qualquer inicialização
  if (kIsWeb) {
    originalUrl = html.window.location.href;
    // Salvar no sessionStorage para sobreviver a reloads
    try {
      html.window.sessionStorage['_original_url'] = originalUrl!;
    } catch (_) {}
  }
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await _autoUpdateIfNeeded();
  await AppLocalizations.initialize();

  // Configuração do ScreenUtil para responsividade total
  await ScreenUtil.ensureScreenSize();

  runApp(ScreenUtilInit(
    designSize: const Size(1920, 1080), // Base desktop
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) {
      return const MyApp();
    },
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  final Map<String, Widget> _activePanels = {};
  bool _needsBootstrap = false;

  @override
  void initState() {
    super.initState();

    // Check if we need to bootstrap (dynamic configuration or cleanup)
    if (kIsWeb) {
      // Always bootstrap on web to ensure config is synced with URL (clearing defaults if at root)
      _needsBootstrap = true;
    }

    // Inicializar instância global
    _globalAppState = this;

    // Carregar preferência do tema do cache
    _loadThemePreference();

    // Adicionar um pequeno delay para garantir que o SharedPreferences carregue
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_needsBootstrap) {
        _checkAuthenticationStatus();
      }
    });

    // Verificação adicional após um tempo maior
    Future.delayed(const Duration(seconds: 2), () {
      if (!_needsBootstrap) {
        _checkAuthenticationStatus();
      }
    });
  }

  //-----------------------------//
  // GERENCIAMENTO DE TEMA
  //-----------------------------//

  /// Carrega a preferência do tema do cache
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString('theme_mode');

      if (themeModeString != null) {
        setState(() {
          switch (themeModeString) {
            case 'dark':
              _themeMode = ThemeMode.dark;
              break;
            case 'light':
              _themeMode = ThemeMode.light;
              break;
            case 'system':
              _themeMode = ThemeMode.system;
              break;
            default:
              _themeMode = ThemeMode.light;
          }
        });
      }
    } catch (e) {
      // Erro ao carregar preferência do tema, usar padrão
    }
  }

  /// Salva a preferência do tema no cache
  Future<void> _saveThemePreference(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeModeString;

      switch (themeMode) {
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        case ThemeMode.system:
          themeModeString = 'system';
          break;
      }

      await prefs.setString('theme_mode', themeModeString);
    } catch (e) {
      // Erro ao salvar preferência do tema
    }
  }

  //-----------------------------//
  // FIM DO GERENCIAMENTO DE TEMA
  //-----------------------------//

  /// Verifica se o usuário está autenticado ao iniciar o app
  Future<void> _checkAuthenticationStatus() async {
    try {
      // REMOVIDO: Prints de debug da inicialização

      final prefs = await SharedPreferences.getInstance();

      // Testar se o SharedPreferences está funcionando
      await prefs.setString('test_key', 'test_value');
      prefs.getString('test_key');
      // REMOVIDO: Print do teste do SharedPreferences

      // Verificar todos os dados salvos
      final encryptedToken = prefs.getString('tokensessao_txt');

      // REMOVIDO: Prints de debug dos tokens e chaves

      if (encryptedToken != null && encryptedToken.isNotEmpty) {
        try {
          // REMOVIDO: Prints de debug da descriptografia

          final token = decryptText(encryptedToken);
          // REMOVIDO: Prints do token descriptografado

          if (token.isNotEmpty) {
            // Token existe e é válido, manter usuário logado
            // REMOVIDO: Print de usuário autenticado
            setState(() {
              _isLoggedIn = true;
              _isLoading = false;
            });
            return;
          }
        } catch (decryptError) {
          // Error decrypting token
        }
      }

      // Token não existe ou é inválido, mostrar tela de login
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  // ThemeData customizado para modo claro
  ThemeData get _lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF7F56D9)),
        cardColor: Colors.white,
        iconTheme: const IconThemeData(
          weight: 400, // Normal weight, não bold
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(
            weight: 400, // Normal weight para ícones do AppBar
          ),
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black, fontSize: 15),
          bodySmall: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(const Color(0xFF1E40AF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E40AF),
            side: const BorderSide(color: Color(0xFF2563EB)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          rangeSelectionBackgroundColor: Color(0xFFD6E4FF),
          rangeSelectionOverlayColor: WidgetStateProperty.all(
              Color(0xFF7F56D9).withValues(alpha: 0.15)),
          todayBackgroundColor:
              WidgetStateProperty.all(Color(0xFF7F56D9).withValues(alpha: 0.2)),
          todayForegroundColor: WidgetStateProperty.all(Colors.white),
          weekdayStyle: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600),
          yearStyle: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600),
          dayStyle: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          headerBackgroundColor: Color(0xFF7F56D9),
          headerForegroundColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.black),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            textStyle:
                WidgetStateProperty.all(TextStyle(fontWeight: FontWeight.bold)),
            shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          ),
        ),
      );

  // ThemeData customizado para modo escuro
  ThemeData get _darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF1E40AF),
        colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF1E40AF), brightness: Brightness.dark),
        cardColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(
          weight: 400, // Normal weight, não bold
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2937),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(
            weight: 400, // Normal weight para ícones do AppBar
          ),
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
          bodySmall: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.all(const Color(0xFF1E40AF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E40AF),
            side: const BorderSide(color: Color(0xFF2563EB)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          rangeSelectionBackgroundColor: Color(0xFF334155),
          rangeSelectionOverlayColor: WidgetStateProperty.all(
              Color(0xFF1E40AF).withValues(alpha: 0.18)),
          todayBackgroundColor:
              WidgetStateProperty.all(Color(0xFF1E40AF).withValues(alpha: 0.3)),
          todayForegroundColor: WidgetStateProperty.all(Colors.white),
          weekdayStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w600),
          yearStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w600),
          dayStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Color(0xFF1E293B),
          surfaceTintColor: Color(0xFF1E293B),
          headerBackgroundColor: Color(0xFF1E40AF),
          headerForegroundColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.black),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            textStyle:
                WidgetStateProperty.all(TextStyle(fontWeight: FontWeight.bold)),
            shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          ),
        ),
      );

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    // Salvar preferência do tema no cache
    _saveThemePreference(_themeMode);
  }

  void _openSidePanel(String panelKey, Widget panel) {
    setState(() {
      _activePanels[panelKey] = panel;
    });
  }

  void _closeSidePanel(String panelKey) {
    setState(() {
      _activePanels.remove(panelKey);
    });
    // Resetar seleção na sidebar quando um painel é fechado
    resetarSelecaoSidebar();
  }

  void _closeAllPanels() {
    setState(() {
      _activePanels.clear();
    });
    // Resetar seleção na sidebar quando todos os painéis são fechados
    resetarSelecaoSidebar();
  }

  // Função global para abrir painéis laterais
  void abrirPainelLateral(String panelKey, Widget panel) {
    setState(() {
      _activePanels[panelKey] = panel;
    });
  }

  // Função global para fechar todos os painéis laterais
  void fecharTodosPaineisLaterais() {
    setState(() {
      _activePanels.clear();
    });
    // Resetar seleção na sidebar quando todos os painéis são fechados
    resetarSelecaoSidebar();
  }

  void _openModal(String modal, BuildContext context) {
    // Fechar todos os painéis ativos antes de abrir um novo
    _closeAllPanels();

    Widget? panelWidget;
    String panelKey;

    switch (modal) {
      case 'alertas':
        panelWidget = AlertasScreen(onClose: () => _closeSidePanel('alertas'));
        panelKey = 'alertas';
        break;
      case 'ocorrencias':
        panelWidget =
            OcorrenciasScreen(onClose: () => _closeSidePanel('ocorrencias'));
        panelKey = 'ocorrencias';
        break;
      case 'ramais':
        panelWidget = RamaisPanel(onClose: () => _closeSidePanel('ramais'));
        panelKey = 'ramais';
        break;
      case 'chaves':
        panelWidget = ChavesModal(onClose: () => _closeSidePanel('chaves'));
        panelKey = 'chaves';
        break;
      case 'turnos':
        panelWidget = TurnosScreen(onClose: () => _closeSidePanel('turnos'));
        panelKey = 'turnos';
        break;
      case 'condominio':
        panelWidget =
            CondominioPanel(onClose: () => _closeSidePanel('condominio'));
        panelKey = 'condominio';
        break;
      case 'ajustes':
        panelWidget = AjustesModal(onClose: () => _closeSidePanel('ajustes'));
        panelKey = 'ajustes';
        break;
      case 'novidades':
        panelWidget =
            NovidadesModal(onClose: () => _closeSidePanel('novidades'));
        panelKey = 'novidades';
        break;
      case 'encomendas':
        panelWidget =
            EncomendasPanel(onClose: () => _closeSidePanel('encomendas'));
        panelKey = 'encomendas';
        break;
      case 'visitantes':
        panelWidget =
            VisitantesPanel(onClose: () => _closeSidePanel('visitantes'));
        panelKey = 'visitantes';
        break;
      case 'unidades':
        panelWidget = UnidadesPanel(onClose: () => _closeSidePanel('unidades'));
        panelKey = 'unidades';
        break;
      case 'vagas':
        panelWidget = VagasPanel(onClose: () => _closeSidePanel('vagas'));
        panelKey = 'vagas';
        break;
      case 'cameras':
        // Modal de câmeras é um pop-up destacável, não um painel lateral
        showCamerasModal(context);
        // Selecionar item correspondente na sidebar
        selecionarItemSidebar('cameras');
        return;
      default:
        // Para outros casos, ainda usa modal
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Modal de teste'),
            content: Text('Você clicou em: $modal'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
        return;
    }

    _openSidePanel(panelKey, panelWidget);

    // Selecionar item correspondente na sidebar
    selecionarItemSidebar(modal);
  }

  void _handleLogin() {
    // Limpar dados antigos antes do novo login
    _clearOldData();

    // Forçar verificação de autenticação após um delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkAuthenticationStatus();
    });

    setState(() {
      _isLoggedIn = true;
    });
  }

  /// Limpa dados antigos que podem causar conflitos
  Future<void> _clearOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limpar dados de layout antigos que podem causar problemas
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.contains('dashboard') ||
            key.contains('layout') ||
            key.contains('card')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Error cleaning old data
    }
  }

  /// Função para fazer logout e limpar dados de autenticação
  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obter token descriptografado para matar a sessão na API
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

      // Matar a sessão na API se tiver token
      if (tokenSessao.isNotEmpty) {
        try {
          final url = Uri.parse(ApiConfig.getEndpoint('auth', 'deleteSession'));
          await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao',
            },
          );

          // Session killed in API
        } catch (e) {
          // Error killing session in API
        }
      }

      // Limpar todos os dados de sessão
      await prefs.remove('tokensessao_txt');
      await prefs.remove('usuario_id');
      await prefs.remove('condominio_id');
      await prefs.remove('usuario_nome');
      await prefs.remove('usuario_email');
      await prefs.remove('condominio_nome');
      await prefs.remove('dashboard_card_order_final');
      await prefs.remove('dashboard_card_order_v2');
      await prefs.remove('dashboard_layout_order');

      // Limpar todos os dados de layout
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.contains('dashboard') ||
            key.contains('layout') ||
            key.contains('card')) {
          await prefs.remove(key);
        }
      }

      // Limpar cache do navegador se estiver no web
      if (kIsWeb) {
        try {
          // Limpar localStorage e sessionStorage
          html.window.localStorage.clear();
          html.window.sessionStorage.clear();

          // Limpar cache do navegador forçando recarga
          // Aguardar um pouco antes de recarregar
          await Future.delayed(const Duration(milliseconds: 500));

          // Recarregar a página para limpar completamente o estado
          html.window.location.reload();
          return; // Sair da função aqui pois a página será recarregada
        } catch (e) {
          // Could not clear browser cache
        }
      }

      setState(() {
        _isLoggedIn = false;
      });
    } catch (e) {
      // Error during logout
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConectCon',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      home: _needsBootstrap
          ? BootstrapPage(onConfigured: () {
              setState(() {
                _needsBootstrap = false;
                _checkAuthenticationStatus();
              });
            })
          : (_isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _isLoggedIn
                  ? (isCamerasView()
                      ? Scaffold(
                          body: CamerasModal(
                            onClose: () {
                              if (kIsWeb) {
                                html.window.close();
                              }
                            },
                          ),
                        )
                      : SidePanelManager(
                          activePanels: _activePanels,
                          onClosePanel: _closeAllPanels,
                          child: MyHomePage(
                            title: 'ConectCon',
                            themeMode: _themeMode,
                            onToggleTheme: _toggleTheme,
                            onOpenModal: (modal, ctx) => _openModal(modal, ctx),
                            activeModal: null,
                            onCloseModal: () {},
                            onLogout: _handleLogout,
                          ),
                        ))
                  : LoginPage(onLogin: _handleLogin)),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => const BootstrapPage());
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final void Function(String modal, BuildContext context) onOpenModal;
  final String? activeModal;
  final VoidCallback onCloseModal;
  final VoidCallback onLogout;

  const MyHomePage({
    super.key,
    required this.title,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onOpenModal,
    required this.activeModal,
    required this.onCloseModal,
    required this.onLogout,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool _editLayoutMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Adicionar listener para detectar quando o usuário sai da página (apenas para web)
    if (kIsWeb) {
      _addBeforeUnloadListener();
    }
  }

  /// Adiciona listener para detectar quando o usuário sai da página
  void _addBeforeUnloadListener() {
    try {
      // Removido logout automático para evitar problemas com Ctrl+F5
    } catch (e) {
      // Could not add page exit listener
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleSidebarModal(String modal, BuildContext context) {
    if (modal == "alterar_layout") {
      setState(() {
        _editLayoutMode = !_editLayoutMode;
      });
      return;
    }
    widget.onOpenModal(modal, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          ThemeToggleProvider(
            onToggle: widget.onToggleTheme,
            child: SidebarDrawer(
              onOpenModal: (modal, ctx) => _handleSidebarModal(modal, ctx),
              onCloseModal: () => fecharTodosPaineisLaterais(),
              onLogout: widget.onLogout,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const DashboardScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const ThemeToggleButton({
    super.key,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isDark ? Icons.wb_sunny : Icons.nightlight_round,
        color: Colors.white, // Ícone branco para sidebar roxa
      ),
      tooltip: 'Alternar tema',
      onPressed: onToggle,
    );
  }
}

// Funções globais para controle de painéis laterais
void abrirPainelLateral(String panelKey, Widget panel) {
  _globalAppState?._openSidePanel(panelKey, panel);
}

void fecharTodosPaineisLaterais() {
  _globalAppState?._closeAllPanels();
  // _closeAllPanels já chama resetarSelecaoSidebar(), então não precisa chamar aqui novamente
}
