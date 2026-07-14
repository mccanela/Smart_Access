import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart'; // <-- NOVO PACOTE DE ROTAS
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
import 'features/modals/noviax_modal.dart' show ConectConIAPanel;
import 'features/modals/cameras_modal.dart'
    show showCamerasModal, isCamerasView, CamerasModal;
import 'features/dashboard/dashboard_panels.dart'
    show EncomendasPanel, VisitantesPanel, UnidadesPanel, VagasPanel;

import 'features/dashboard/dashboard.dart' show DashboardScreen;
import 'features/auth/login.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/crypto_utils.dart';
import 'core/config/api_config.dart';
import 'features/bootstrap/bootstrap_page.dart';
import 'core/config/app_version.dart';

//-----------------------------//
// SISTEMA DE PÁGINAS LATERAIS
//-----------------------------//

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
    for (final key in widget.activePanels.keys) {
      if (!_controllers.containsKey(key)) {
        _controllers[key] = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        )..forward();
      }
    }
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
        widget.child,
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

    double leftPos = screenWidth - panelWidth;
    if (leftPos < sidebarRightBoundary && screenWidth < 1440) {
      panelWidth = screenWidth - sidebarRightBoundary - 10;
    }

    return panelWidth;
  }
}

abstract class SidePanel extends StatefulWidget {
  final VoidCallback onClose;
  const SidePanel({super.key, required this.onClose});
  String get panelKey;

  @override
  State<SidePanel> createState();
}

// Controlador Global do Fluxo Atualizado
_ClientAppFlowState? _globalFlowState;

void abrirPainelLateral(String panelKey, Widget panel) {
  _globalFlowState?._openSidePanel(panelKey, panel);
}

void fecharTodosPaineisLaterais() {
  _globalFlowState?._closeAllPanels();
}

//-----------------------------//
// INICIALIZAÇÃO
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
      // O dart:html foi removido daqui para garantir compatibilidade com WASM.
      // A gestão de cache na Web deverá agora ser feita pelo Service Worker padrão do Flutter.
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await _autoUpdateIfNeeded();
  await AppLocalizations.initialize();
  await ScreenUtil.ensureScreenSize();

  runApp(ScreenUtilInit(
    designSize: const Size(1920, 1080),
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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();

    // IMPLEMENTAÇÃO GO_ROUTER
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ClientAppFlow(
            slug: '',
            themeMode: _themeMode,
            onToggleTheme: _toggleTheme,
          ),
        ),
        GoRoute(
          path: '/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ClientAppFlow(
              slug: slug,
              themeMode: _themeMode,
              onToggleTheme: _toggleTheme,
            );
          },
        ),
      ],
      errorBuilder: (context, state) => const Scaffold(
        body: Center(child: Text('Página não encontrada (Erro 404).')),
      ),
    );
  }

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
    } catch (e) {}
  }

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
    } catch (e) {}
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveThemePreference(_themeMode);
  }

  ThemeData get _lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7F56D9)),
        cardColor: Colors.white,
        iconTheme: const IconThemeData(weight: 400),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(weight: 400),
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
          rangeSelectionBackgroundColor: const Color(0xFFD6E4FF),
          rangeSelectionOverlayColor: WidgetStateProperty.all(
              const Color(0xFF7F56D9).withValues(alpha: 0.15)),
          todayBackgroundColor: WidgetStateProperty.all(
              const Color(0xFF7F56D9).withValues(alpha: 0.2)),
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
          headerBackgroundColor: const Color(0xFF7F56D9),
          headerForegroundColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.black),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            textStyle:
                WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.bold)),
            shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          ),
        ),
      );

  ThemeData get _darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF1E40AF),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E40AF), brightness: Brightness.dark),
        cardColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(weight: 400),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F2937),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(weight: 400),
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
          rangeSelectionBackgroundColor: const Color(0xFF334155),
          rangeSelectionOverlayColor: WidgetStateProperty.all(
              const Color(0xFF1E40AF).withValues(alpha: 0.18)),
          todayBackgroundColor: WidgetStateProperty.all(
              const Color(0xFF1E40AF).withValues(alpha: 0.3)),
          todayForegroundColor: WidgetStateProperty.all(Colors.white),
          weekdayStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w600),
          yearStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w600),
          dayStyle: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFF1E293B),
          surfaceTintColor: const Color(0xFF1E293B),
          headerBackgroundColor: const Color(0xFF1E40AF),
          headerForegroundColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.black),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            textStyle:
                WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.bold)),
            shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ConectCon',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      routerConfig: _router,
    );
  }
}

//-----------------------------//
// FLUXO PRINCIPAL DA APLICAÇÃO
//-----------------------------//

class ClientAppFlow extends StatefulWidget {
  final String slug;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const ClientAppFlow({
    super.key,
    required this.slug,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<ClientAppFlow> createState() => _ClientAppFlowState();
}

class _ClientAppFlowState extends State<ClientAppFlow> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  bool _isBootstrapping = true;
  final Map<String, Widget> _activePanels = {};

  @override
  void initState() {
    super.initState();
    _globalFlowState = this;

    // Se a sigla estiver vazia ou for acedida a raiz, poderás adaptar o comportamento.
    // Atualmente força o bootstrap de qualquer forma.
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkAuthenticationStatus();
    });
  }

  @override
  void didUpdateWidget(covariant ClientAppFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      setState(() {
        _isBootstrapping = true;
      });
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');

      if (encryptedToken != null && encryptedToken.isNotEmpty) {
        try {
          final token = decryptText(encryptedToken);
          if (token.isNotEmpty) {
            setState(() {
              _isLoggedIn = true;
              _isLoading = false;
            });
            return;
          }
        } catch (_) {}
      }

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

  void _openSidePanel(String panelKey, Widget panel) {
    setState(() {
      _activePanels[panelKey] = panel;
    });
  }

  void _closeSidePanel(String panelKey) {
    setState(() {
      _activePanels.remove(panelKey);
    });
    resetarSelecaoSidebar();
  }

  void _closeAllPanels() {
    setState(() {
      _activePanels.clear();
    });
    resetarSelecaoSidebar();
  }

  void _openModal(String modal, BuildContext context) {
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
      case 'noviax':
        panelWidget =
            ConectConIAPanel(onClose: () => _closeSidePanel('noviax'));
        panelKey = 'noviax';
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
        showCamerasModal(context);
        selecionarItemSidebar('cameras');
        return;
      default:
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Modal de teste'),
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
    selecionarItemSidebar(modal);
  }

  void _handleLogin() {
    _clearOldData();
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkAuthenticationStatus();
    });
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> _clearOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.contains('dashboard') ||
            key.contains('layout') ||
            key.contains('card')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {}
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

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
        } catch (e) {}
      }

      await prefs.remove('tokensessao_txt');
      await prefs.remove('usuario_id');
      await prefs.remove('condominio_id');
      await prefs.remove('usuario_nome');
      await prefs.remove('usuario_email');
      await prefs.remove('condominio_nome');
      await prefs.remove('dashboard_card_order_final');
      await prefs.remove('dashboard_card_order_v2');
      await prefs.remove('dashboard_layout_order');

      await _clearOldData();

      // Sem recarregamento de página web por motivos de compatibilidade. O setState fará o retorno ao login.
      setState(() {
        _isLoggedIn = false;
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      // O teu componente Bootstrap deve estar preparado para ler a sigla que passas pela URL
      // (caso não esteja, ele deve ler o SharedPreferences, que configuraste na tua adaptação da página de login).
      return BootstrapPage(
        onConfigured: () {
          setState(() {
            _isBootstrapping = false;
            _checkAuthenticationStatus();
          });
        },
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return LoginPage(onLogin: _handleLogin);
    }

    if (isCamerasView()) {
      return Scaffold(
        body: CamerasModal(
          onClose: () {
            // Se necessário, podes usar um `context.pop()` em vez de tentar fechar a aba
          },
        ),
      );
    }

    return SidePanelManager(
      activePanels: _activePanels,
      onClosePanel: _closeAllPanels,
      child: MyHomePage(
        title: 'ConectCon',
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
        onOpenModal: _openModal,
        activeModal: null,
        onCloseModal: () {},
        onLogout: _handleLogout,
      ),
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
          const Expanded(
            child: Stack(
              children: [
                DashboardScreen(),
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
        color: Colors.white,
      ),
      tooltip: 'Alternar tema',
      onPressed: onToggle,
    );
  }
}