import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  static const String _languageKey = 'app_language';
  static const String _defaultLanguage = 'pt';
  
  static final Map<String, Map<String, String>> _translations = {
    'pt': {
      // Login
      'login': 'Login',
      'password': 'Senha',
      'remember_me': 'Lembrar-me',
      'connect': 'Conectar',
      'new_password': 'Nova Senha',
      'request_access': 'Solicitar Acesso',
      'captcha': 'Captcha',
      'enter_captcha_result': 'Digite o resultado do captcha',
      'fill_user_password': 'Preencha usuário e senha.',
      'wrong_credentials': 'Usuário ou senha estão errados.',
      'connection_error': 'Erro de conexão. Tente novamente.',
      'session_token_error': 'Token de sessão não retornado pelo servidor. Faça login novamente.',
      
      // Dashboard
      'dashboard': 'Dashboard',
      'welcome': 'Bem-vindo',
      'smart_management': 'Gestão Inteligente',
      
      // Sidebar
      'home': 'Início',
      'alerts': 'Alertas',
      'keys': 'Chaves',
      'condominium': 'Condomínio',
      'occurrences': 'Ocorrências',
      'extensions': 'Ramais',
      'shifts': 'Turnos',
      'schedules': 'Agendamentos',
      'packages': 'Entregas',
      'logout': 'Sair',
      
      // Turnos
      'register_shift_changes': 'Registre situações de troca de turno.',
      'new_shift': 'Novo Turno',
      'history': 'Histórico',
      'is_leaving': 'Está Saindo',
      'is_entering': 'Está Entrando',
      'reason': 'Motivo',
      'observation': 'Observação',
      'click_to_select_user': 'Clique para selecionar o usuário',
      'register': 'Registrar',
      'registering': 'Registrando...',
      'select_user': 'Selecionar Usuário',
      'search_user': 'Buscar usuário...',
      'no_user_found': 'Nenhum usuário encontrado.',
      'total_users_loaded': 'Total de usuários carregados',
      'user_selected': 'Usuário selecionado',
      'fill_required_fields': 'Preencha todos os campos obrigatórios',
      'shift_registered_success': 'Turno registrado com sucesso!',
      'error_registering_shift': 'Erro ao registrar turno',
      'shift_change': 'Troca de Turno',
      'leaving': 'SAINDO',
      'entering': 'ENTRANDO',
      'user': 'Usuário',
      'date_time': 'Data/Hora',
      'logout_question': 'Deseja deslogar?',
      'logout_shift_message': 'Deseja sair do sistema para que o próximo operador possa fazer login?',
      'yes': 'Sim',
      'no': 'Não',
      'active_shift_observation': 'Observação do Turno Ativo',
      'last_shift_observation_message': 'Você tem um turno ativo. Aqui está a última observação:',
      'ok': 'OK',
      
      // Alertas
      'manage_alerts': 'Gerencie os alertas do sistema.',
      
      // Chaves
      'manage_keys': 'Gerencie as chaves do condomínio.',
      
      // Condomínio
      
      'manage_condominium': 'Gerencie as informações do condomínio.',
      
      // Ocorrências
     
      'manage_occurrences': 'Gerencie as ocorrências do condomínio.',
      
      // Ramais
     
      'manage_extensions': 'Gerencie os ramais do condomínio.',
      
      // Geral
      'close': 'Fechar',
      'loading': 'Carregando...',
      'error': 'Erro',
      'success': 'Sucesso',
      'cancel': 'Cancelar',
      'save': 'Salvar',
      'edit': 'Editar',
      'delete': 'Excluir',
      'confirm': 'Confirmar',
      'no_data_found': 'Nenhum dado encontrado.',
      'unknown_error': 'Erro desconhecido',
      'select_language': 'Selecionar Idioma',
      'change_layout': 'Alterar Layout',
      'entrance': 'ENTRADA',
      'access_control_system': 'Sistema de Controle de Acesso',
      'new_occurrence': 'Nova Ocorrência',
      'date': 'Data',
      'reported_by': 'Reportado por...',
      'doorman': 'Porteiro',
      'manager': 'Síndico',
      'resident': 'Morador',
      'occurrence_location': 'Local da Ocorrência...',
      'occurrence_description': 'Descrição da Ocorrência...',
      'key_delivery': 'Entrega de Chave',
      'key_name': 'Nome da chave...',
      'search_key': 'Buscar chave...',
      'for_unit_person_company': 'Para Unidade, Pessoa ou Empresa...',
      'search_unit': 'Buscar unidade...',
      'key_history': 'Histórico de Chaves',
      'start_date': 'Data início',
      'end_date': 'Data fim',
      'select_date': 'Selecionar data',
      'address': 'Endereço',
      'governing_body': 'Corpo Diretivo',
      'internal_regulations': 'Regimento Interno',
      'parking_map': 'Mapa de Vagas',
      'error_loading_address': 'Erro ao carregar endereço',
      'select': 'Selecionar',
      'filter_by_date': 'Filtrar por data...',
      'clear': 'Limpar',
      'filter_by_name': 'Filtrar por nome...',
      'exit_auto_checkout_mode': 'Sair do modo Auto Baixa',
      'auto_checkout': 'Auto Baixa',
      'delivery_id_not_found': 'ID de entrega não encontrado.',
      'yes_take_photo': 'Sim, tirar foto',
      'no_checkout_records_found': 'Nenhum registro de baixa encontrado.',
      'entrance_registered_success': 'Entrada cadastrada com sucesso!',
      'package_registered_success': 'Encomenda registrada com sucesso!',
      'error_registering_package': 'Erro ao registrar encomenda.',
      'action_completed_success': 'Ação realizada com sucesso!',
      'filtered_result': 'Resultado Filtrado',
      'filter_by_unit': 'Filtrar por unidade...',
      'withdrawn_by': 'Retirado por:',
      'delivered_by': 'Entregue por:',
      'withdrawal_token': 'Token de retirada',
      'token': 'Token',
      'message': 'Mensagem',
      'temporary_rental_scheduling': 'Agendamento de Locação Temporária',
      'add_to_list': 'Incluir na Lista',
      'passage_history': 'Histórico de Passagens',
      'view_passages_registered_by_access_controls': 'Visualize aqui as passagens registradas pelos controles de acesso.',
      'unit_or_name': 'Unidade ou Nome...',
      'type': 'Tipo...',
      'pickup_location': 'Local de Retirada...',
      'detail_or_code': 'Detalhe ou Código...',
      'deliver': 'Entregar',
      'send': 'Enviar',
      'mail_center': 'Central de Correspondências',
      'document': 'Documento',
      'full_name': 'Nome e Sobrenome',
      'service_provider': 'P. Serviço',
      'visitor': 'Visitante',
      'name_or_unit': 'Nome ou unidade...',
      'authorizer': 'Autorizante',
      'company': 'Empresa',
      'brand': 'Marca',
      'color': 'Cor',
      'vehicle_model': 'Modelo Veículo',
      'license_plate': 'Placa',
      'name': 'Nome',
      'important_info_for_reception': 'Informações importantes para a portaria.',
      'required_field': 'Campo obrigatório',
      'batch_checkout': 'Baixa em Lote',
      'exit': 'Saida',
      'search': 'Pesquisar',
    },
    'en': {
      // Login
      'login': 'Login',
      'password': 'Password',
      'remember_me': 'Remember me',
      'connect': 'Connect',
      'new_password': 'New Password',
      'request_access': 'Request Access',
      'captcha': 'Captcha',
      'enter_captcha_result': 'Enter the captcha result',
      'fill_user_password': 'Please fill in username and password.',
      'wrong_credentials': 'Username or password is incorrect.',
      'connection_error': 'Connection error. Please try again.',
      'session_token_error': 'Session token not returned by server. Please login again.',
      
      // Dashboard
      'dashboard': 'Dashboard',
      'welcome': 'Welcome',
      'smart_management': 'Smart Management',
      
      // Sidebar
      'home': 'Home',
      'alerts': 'Alerts',
      'keys': 'Keys',
      'condominium': 'Condominium',
      'occurrences': 'Occurrences',
      'extensions': 'Extensions',
      'shifts': 'Shifts',
      'schedules': 'Schedules',
      'packages': 'Packages',
      'logout': 'Logout',
      
      // Turnos
      'register_shift_changes': 'Register shift change situations.',
      'new_shift': 'New Shift',
      'history': 'History',
      'is_leaving': 'Is Leaving',
      'is_entering': 'Is Entering',
      'reason': 'Reason',
      'observation': 'Observation',
      'click_to_select_user': 'Click to select user',
      'register': 'Register',
      'registering': 'Registering...',
      'select_user': 'Select User',
      'search_user': 'Search user...',
      'no_user_found': 'No user found.',
      'total_users_loaded': 'Total users loaded',
      'user_selected': 'User selected',
      'fill_required_fields': 'Please fill in all required fields',
      'shift_registered_success': 'Shift registered successfully!',
      'error_registering_shift': 'Error registering shift',
      'shift_change': 'Shift Change',
      'leaving': 'LEAVING',
      'entering': 'ENTERING',
      'user': 'User',
      'date_time': 'Date/Time',
      'logout_question': 'Do you want to logout?',
      'logout_shift_message': 'Do you want to exit the system so the next operator can login?',
      'yes': 'Yes',
      'no': 'No',
      'active_shift_observation': 'Active Shift Observation',
      'last_shift_observation_message': 'You have an active shift. Here is the last observation:',
      'ok': 'OK',
      
      // Alertas
      'manage_alerts': 'Manage system alerts.',
      
      // Chaves
      'manage_keys': 'Manage condominium keys.',
      
      // Condomínio
     
      'manage_condominium': 'Manage condominium information.',
      
      // Ocorrências
      
      'manage_occurrences': 'Manage condominium occurrences.',
      
      // Ramais
    
      'manage_extensions': 'Manage condominium extensions.',
      
      // Geral
      'close': 'Close',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'save': 'Save',
      'edit': 'Edit',
      'delete': 'Delete',
      'confirm': 'Confirm',
      'no_data_found': 'No data found.',
      'unknown_error': 'Unknown error',
      'select_language': 'Select Language',
      'change_layout': 'Change Layout',
      'entrance': 'ENTRANCE',
      'access_control_system': 'Access Control System',
      'reservation_system': 'Reservation System',
      'package_management': 'Package Management',
      'title': 'Title',
      'description': 'Description',
      'photo': 'Photo',
      'new_alert': 'New Alert',
      'alert_type': 'Alert type',
      'alert_description': 'Alert Description...',
      'emergency': 'Emergency',
      'security': 'Security',
      'maintenance': 'Maintenance',
      'new_occurrence': 'New Occurrence',
      'date': 'Date',
      'reported_by': 'Reported by...',
      'doorman': 'Doorman',
      'manager': 'Manager',
      'resident': 'Resident',
      'occurrence_location': 'Occurrence Location...',
      'occurrence_description': 'Occurrence Description...',
      'key_delivery': 'Key Delivery',
      'key_name': 'Key name...',
      'search_key': 'Search key...',
      'for_unit_person_company': 'For Unit, Person or Company...',
      'search_unit': 'Search unit...',
      'key_history': 'Key History',
      'start_date': 'Start date',
      'end_date': 'End date',
      'address': 'Address',
      'governing_body': 'Governing Body',
      'internal_regulations': 'Internal Regulations',
      'parking_map': 'Parking Map',
      'error_loading_address': 'Error loading address',
      'select': 'Select',
      'filter_by_date': 'Filter by date...',
      'clear': 'Clear',
      'filter_by_name': 'Filter by name...',
      'exit_auto_checkout_mode': 'Exit auto checkout mode',
      'auto_checkout': 'Auto Checkout',
      'delivery_id_not_found': 'Delivery ID not found.',
      'yes_take_photo': 'Yes, take photo',
      'no_checkout_records_found': 'No checkout records found.',
      'entrance_registered_success': 'Entrance registered successfully!',
      'package_registered_success': 'Package registered successfully!',
      'error_registering_package': 'Error registering package.',
      'action_completed_success': 'Action completed successfully!',
      'filtered_result': 'Filtered Result',
      'filter_by_unit': 'Filter by unit...',
      'withdrawn_by': 'Withdrawn by:',
      'delivered_by': 'Delivered by:',
      'withdrawal_token': 'Withdrawal token',
      'token': 'Token',
      'message': 'Message',
      'temporary_rental_scheduling': 'Temporary Rental Scheduling',
      'add_to_list': 'Add to List',
      'passage_history': 'Passage History',
      'view_passages_registered_by_access_controls': 'View here the passages registered by access controls.',
      'unit_or_name': 'Unit or Name...',
      'type': 'Type...',
      'pickup_location': 'Pickup Location...',
      'detail_or_code': 'Detail or Code...',
      'deliver': 'Deliver',
      'send': 'Send',
      'mail_center': 'Mail Center',
      'document': 'Document',
      'full_name': 'Full Name',
      'service_provider': 'Service Provider',
      'visitor': 'Visitor',
      'name_or_unit': 'Name or unit...',
      'authorizer': 'Authorizer',
      'company': 'Company',
      'brand': 'Brand',
      'color': 'Color',
      'vehicle_model': 'Vehicle Model',
      'license_plate': 'License Plate',
      'name': 'Name',
      'important_info_for_reception': 'Important information for reception.',
      'required_field': 'Required field',
      'batch_checkout': 'Batch Checkout',
      'exit': 'Exit',
      'search': 'Search',
    },
  };

  static String _currentLanguage = _defaultLanguage;

  static String get currentLanguage => _currentLanguage;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? _defaultLanguage;
  }

  static Future<void> setLanguage(String languageCode) async {
    if (_translations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    }
  }

  static String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? _translations[_defaultLanguage]?[key] ?? key;
  }

  static Map<String, String> get availableLanguages => {
    'pt': 'Português',
    'en': 'English',
  };

  static String getLanguageName(String languageCode) {
    return availableLanguages[languageCode] ?? languageCode;
  }
} 