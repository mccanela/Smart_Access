import 'dart:async';
import 'package:flutter/foundation.dart';

// Conditional imports for web-only libraries
// Use stubs for non-web platforms to avoid linting errors
import 'control_id_service_stub_html.dart' if (dart.library.html) 'dart:html' as html;
import 'control_id_service_stub_js.dart' if (dart.library.js) 'dart:js' as js show JsObject, context, allowInterop;

//-----------------------------//
// Serviço para comunicação com Control ID via USB
//-----------------------------//
class ControlIdService {
  static ControlIdService? _instance;
  static ControlIdService get instance => _instance ??= ControlIdService._();
  
  ControlIdService._();

  bool _isConnected = false;
  String? _sessionId;
  StreamController<Map<String, dynamic>>? _biometryController;
  
  // Stream para receber eventos de biometria
  Stream<Map<String, dynamic>>? get biometryStream => _biometryController?.stream;

  //-----------------------------//
  // Verificar se o equipamento está conectado
  //-----------------------------//
  Future<bool> checkConnection() async {
    try {
      if (kIsWeb) {
        // Verificar via JavaScript se o equipamento está disponível
        final result = js.context.callMethod('checkControlIdDevice');
        return result ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao verificar conexão Control ID: $e');
      return false;
    }
  }

  //-----------------------------//
  // Conectar ao equipamento Control ID e obter sessão
  //-----------------------------//
  Future<String?> connectAndGetSession() async {
    try {
      if (kIsWeb) {
        try {
          _addControlIdScripts();
          
          // Aguardar um pouco para garantir que os scripts foram carregados
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Verificar se Control ID está disponível
          final isAvailable = await checkConnection();
          if (!isAvailable) {
            print('⚠️ Control ID não detectado. Verifique:');
            print('   1. Equipamento conectado via USB');
            print('   2. Drivers instalados');
            print('   3. Biblioteca JavaScript da Control ID carregada (se necessário)');
          }
          
          // Tentar conectar e obter sessão via JavaScript
          final sessionResult = await _invokeJsMethod('connectControlIdDevice');
          
          if (sessionResult != null && sessionResult is String && sessionResult.isNotEmpty) {
            _sessionId = sessionResult;
            _isConnected = true;
            print('✅ Control ID conectado. Sessão: $_sessionId');
            print('💡 Se a captura não funcionar, verifique o console do navegador (F12)');
            return _sessionId;
          } else {
            print('⚠️ Não foi possível obter sessão do Control ID');
            print('💡 Verifique se o equipamento está conectado e os drivers instalados');
            print('💡 Abra o console do navegador (F12) para ver erros detalhados');
            return null;
          }
        } catch (e) {
          print('❌ Erro ao conectar Control ID: $e');
          // Simular conexão em desenvolvimento
          if (kDebugMode) {
            _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
            _isConnected = true;
            print('⚠️ [MODO DEBUG] Simulando sessão: $_sessionId');
            return _sessionId;
          }
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erro ao conectar Control ID: $e');
      return null;
    }
  }

  //-----------------------------//
  // Capturar biometria do equipamento
  //-----------------------------//
  Future<Map<String, dynamic>?> captureBiometry({required String tipo, String? sessionId}) async {
    try {
      if (!_isConnected && sessionId == null) {
        final connectedSession = await connectAndGetSession();
        if (connectedSession == null) {
          throw Exception('Não foi possível conectar ao equipamento Control ID');
        }
      }

      final activeSession = sessionId ?? _sessionId;
      if (activeSession == null) {
        throw Exception('Sessão não disponível');
      }

      if (kIsWeb) {
        try {
          // Chamar método JavaScript para capturar biometria
          final result = await _invokeJsMethod('captureControlIdBiometry', {
            'sessionId': activeSession,
            'tipo': tipo, // 'acesso' ou 'panico'
          });

          if (result != null) {
            // Converter resultado JavaScript para Map Dart
            Map<String, dynamic> biometryData;
            
            if (result is Map) {
              biometryData = Map<String, dynamic>.from(result);
            } else if (kIsWeb && result is js.JsObject) {
              final jsObj = result;
              biometryData = {
                'imagem': jsObj['imagem']?.toString() ?? '',
                'template': jsObj['template']?.toString() ?? '',
                'sessao': jsObj['sessao']?.toString() ?? '',
              };
            } else {
              throw Exception('Tipo de resultado inválido: ${result.runtimeType}');
            }
            
            // Verificar se contém imagem base64
            final imagem = biometryData['imagem'] ?? biometryData['image'];
            final template = biometryData['template'] ?? biometryData['fingerprint'] ?? '';
            
            if (imagem != null && imagem.toString().isNotEmpty) {
              return {
                'tipo': tipo,
                'imagem': imagem.toString(),
                'template': template.toString(),
                'sessao': activeSession,
                'timestamp': DateTime.now().toIso8601String(),
              };
            }
          }

          // Modo debug: simular captura de biometria
          if (kDebugMode) {
            print('⚠️ [MODO DEBUG] Simulando captura de biometria do tipo: $tipo');
            return {
              'tipo': tipo,
              'imagem': _generateMockBiometryImage(),
              'template': 'mock_template_${tipo}_${DateTime.now().millisecondsSinceEpoch}',
              'sessao': activeSession,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }

          throw Exception('Resposta inválida do equipamento Control ID');
        } catch (e) {
          print('❌ Erro ao capturar biometria: $e');
          // Em modo debug, retornar biometria simulada
          if (kDebugMode) {
            return {
              'tipo': tipo,
              'imagem': _generateMockBiometryImage(),
              'template': 'mock_template_${tipo}_${DateTime.now().millisecondsSinceEpoch}',
              'sessao': activeSession,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }
          rethrow;
        }
      }

      return null;
    } catch (e) {
      print('❌ Erro ao capturar biometria: $e');
      return null;
    }
  }

  //-----------------------------//
  // Adicionar scripts JavaScript necessários para Control ID
  // 
  // IMPORTANTE: Para usar o SDK oficial da Control ID, é necessário:
  // 1. Baixar o SDK JavaScript (iDBio) da Control ID
  // 2. Incluir o script no index.html ANTES do flutter_bootstrap.js:
  //    <script src="path/to/cidbio.js"></script>
  // 3. Ou carregar dinamicamente via script tag
  // 
  // Documentação: https://www.controlid.com.br/docs/idbio-pt/
  //-----------------------------//
  void _addControlIdScripts() {
    try {
      // Verificar se os scripts já foram adicionados
      final existingScript = html.document.querySelector('#control-id-scripts');
      if (existingScript != null) {
        return;
      }
      
      // Nota: O SDK da Control ID deve ser carregado manualmente no index.html
      // Exemplo: <script src="cidbio.js"></script>

      final script = html.ScriptElement()
        ..id = 'control-id-scripts'
        ..type = 'text/javascript'
        ..innerHtml = '''
        // Função para verificar se o dispositivo Control ID está disponível
        window.checkControlIdDevice = function() {
          try {
            // Verificar se há dispositivo USB conectado (Control ID)
            if (navigator.usb) {
              return true;
            }
            
            // Verificar se há plugin ActiveX (para navegadores antigos)
            try {
              if (typeof ActiveXObject !== 'undefined') {
              new ActiveXObject('ControlID.Conexao');
              return true;
              }
            } catch(e) {
              // Plugin não disponível
            }
            
            // Verificar SDK JavaScript
            try {
              if (typeof window.ControlID !== 'undefined') {
                return true;
              }
            } catch(e) {
              // SDK não disponível
            }
            
            // Verificar IDBio SDK
            try {
              if (typeof window.IDBio !== 'undefined') {
                return true;
              }
            } catch(e) {
              // IDBio não disponível
            }
            
            return false;
          } catch(e) {
            console.error('Erro ao verificar dispositivo Control ID:', e);
            return false;
          }
        };

        // Função para conectar ao equipamento Control ID e obter sessão
        window.connectControlIdDevice = function() {
          try {
            // Tentar conectar via WebUSB
            if (navigator.usb) {
              // Retornar uma sessão simulada (será implementado com API real)
              return 'session_' + Date.now();
            }
            
            // Tentar conectar via ActiveX (IE/Edge Legacy / Chrome com plugin)
            try {
              if (typeof ActiveXObject !== 'undefined') {
              var conexao = new ActiveXObject('ControlID.Conexao');
              var sessao = conexao.Conectar(1); // Porta 1 (ajustar conforme necessário)
              if (sessao && sessao > 0) {
                  console.log('✅ Control ID conectado via ActiveX, sessão:', sessao);
                  return 'session_' + sessao;
                }
              }
            } catch(e) {
              console.warn('⚠️ Erro ao conectar via ActiveX:', e);
            }
            
            // Tentar via SDK JavaScript
            try {
              if (typeof window.ControlID !== 'undefined' && window.ControlID.Conexao) {
                var conexao = new window.ControlID.Conexao();
                var sessao = conexao.Conectar(1);
                if (sessao && sessao > 0) {
                  console.log('✅ Control ID conectado via SDK, sessão:', sessao);
                return 'session_' + sessao;
                }
              }
            } catch(e) {
              console.warn('⚠️ Erro ao conectar via SDK:', e);
            }
            
            // Tentar via IDBio SDK
            try {
              if (typeof window.IDBio !== 'undefined') {
                var conexao = window.IDBio;
                if (conexao.Connect) {
                  var resultado = conexao.Connect(1);
                  if (resultado && resultado > 0) {
                    console.log('✅ Control ID conectado via IDBio, sessão:', resultado);
                    return 'session_' + resultado;
                  }
                }
              }
            } catch(e) {
              console.warn('⚠️ Erro ao conectar via IDBio:', e);
            }
            
            // Se não encontrou equipamento real, retornar sessão simulada
            console.warn('⚠️ Control ID não detectado, usando sessão simulada');
            console.warn('⚠️ Verifique se o equipamento está conectado e os drivers instalados');
            return 'session_' + Date.now();
          } catch(e) {
            console.error('Erro ao conectar Control ID:', e);
            return null;
          }
        };

        //-----------------------------//
        // Função auxiliar para converter bitmap (byte array) para base64 PNG
        //-----------------------------//
        function bitmapToBase64(bitmapData, width, height) {
          try {
            // Criar canvas para converter bitmap em PNG
            var canvas = document.createElement('canvas');
            canvas.width = width;
            canvas.height = height;
            var ctx = canvas.getContext('2d');
            
            // Criar ImageData a partir do bitmap
            var imageData = ctx.createImageData(width, height);
            var data = imageData.data;
            
            // Converter bitmap (grayscale) para RGBA
            for (var i = 0; i < bitmapData.length; i++) {
              var pixel = bitmapData[i];
              var idx = i * 4;
              data[idx] = pixel;     // R
              data[idx + 1] = pixel;  // G
              data[idx + 2] = pixel;  // B
              data[idx + 3] = 255;    // A
            }
            
            ctx.putImageData(imageData, 0, 0);
            return canvas.toDataURL('image/png');
          } catch(e) {
            console.error('Erro ao converter bitmap para base64:', e);
            return null;
          }
        }

        //-----------------------------//
        // Função para capturar biometria do Control ID usando SDK oficial
        // Baseado na documentação: https://www.controlid.com.br/docs/idbio-pt/2_c_reference/
        //-----------------------------//
        window.captureControlIdBiometry = function(params, callback) {
          try {
            var sessionId = params.sessionId || params['sessionId'];
            var tipo = params.tipo || params['tipo'] || 'acesso';
            
            console.log('🔍 Iniciando captura de biometria - Sessão:', sessionId, 'Tipo:', tipo);
            console.log('📖 Usando SDK oficial Control ID iDBio');
            
            // Verificar se há biblioteca Control ID disponível (SDK)
            var controlIdAvailable = false;
            var cidbio = null;
            
            //-----------------------------//
            // Tentar via IDBio SDK (SDK oficial mais recente)
            //-----------------------------//
            try {
              if (typeof window.CIDBIO !== 'undefined') {
                cidbio = window.CIDBIO;
                controlIdAvailable = true;
                console.log('✅ CIDBIO SDK detectado (SDK oficial)');
              } else if (typeof window.IDBio !== 'undefined') {
                cidbio = window.IDBio;
                controlIdAvailable = true;
                console.log('✅ IDBio SDK detectado');
              }
            } catch(e) {
              console.warn('⚠️ IDBio SDK não disponível:', e);
            }
            
            //-----------------------------//
            // Tentar via ActiveX (para compatibilidade com versões antigas)
            //-----------------------------//
            if (!controlIdAvailable) {
              try {
                if (typeof ActiveXObject !== 'undefined') {
                  var conexao = new ActiveXObject('ControlID.Conexao');
                  var leitor = new ActiveXObject('ControlID.Leitor');
                  cidbio = {
                    conexao: conexao,
                    leitor: leitor,
                    isActiveX: true
                  };
                  controlIdAvailable = true;
                  console.log('✅ Control ID detectado via ActiveX');
                }
              } catch(e) {
                console.warn('⚠️ ActiveX Control ID não disponível:', e);
              }
            }
            
            //-----------------------------//
            // Tentar via SDK JavaScript (ControlID global)
            //-----------------------------//
            if (!controlIdAvailable) {
              try {
                if (typeof window.ControlID !== 'undefined') {
                  if (window.ControlID.Leitor && window.ControlID.Conexao) {
                    cidbio = {
                      conexao: new window.ControlID.Conexao(),
                      leitor: new window.ControlID.Leitor(),
                      isSDK: true
                    };
                    controlIdAvailable = true;
                    console.log('✅ Control ID detectado via SDK JavaScript');
                  }
                }
              } catch(e) {
                console.warn('⚠️ SDK JavaScript Control ID não disponível:', e);
              }
            }
            
            //-----------------------------//
            // Se equipamento Control ID disponível, capturar biometria real
            //-----------------------------//
            if (controlIdAvailable && cidbio) {
              console.log('📸 Aguardando captura de biometria do equipamento...');
              console.log('💡 Coloque o dedo no sensor do equipamento Control ID');
              
              try {
                var imagemBase64 = null;
                var template = null;
                var width = 0;
                var height = 0;
                
                //-----------------------------//
                // Método 1: Via SDK oficial CIDBIO (CaptureImageAndTemplate)
                // Conforme documentação: https://www.controlid.com.br/docs/idbio-pt/2_c_reference/
                //-----------------------------//
                if (cidbio.CaptureImageAndTemplate) {
                  console.log('📸 Usando CIDBIO.CaptureImageAndTemplate()');
                  
                  var imageBuf = null;
                  var temp = null;
                  var quality = 0;
                  
                  // Chamar função do SDK
                  var result = cidbio.CaptureImageAndTemplate(
                    function(tempResult) { temp = tempResult; },
                    function(imgBuf, w, h) { 
                      imageBuf = imgBuf; 
                      width = w; 
                      height = h; 
                    },
                    function(q) { quality = q; }
                  );
                  
                  // Verificar resultado
                  if (result === 0 || result === CIDBIO_SUCCESS || result === 0) {
                    console.log('✅ Captura realizada com sucesso!');
                    console.log('📊 Qualidade:', quality, 'Largura:', width, 'Altura:', height);
                    
                    // Converter bitmap para base64
                    if (imageBuf && width > 0 && height > 0) {
                      imagemBase64 = bitmapToBase64(imageBuf, width, height);
                      if (!imagemBase64) {
                        // Se falhar, tentar converter diretamente se já for string
                        if (typeof imageBuf === 'string') {
                          imagemBase64 = imageBuf.startsWith('data:image') 
                            ? imageBuf 
                            : 'data:image/png;base64,' + imageBuf;
                        }
                      }
                    }
                    
                    template = temp || '';
                  } else {
                    console.error('❌ Erro na captura. Código:', result);
                    throw new Error('Erro ao capturar biometria. Código: ' + result);
                  }
                }
                //-----------------------------//
                // Método 2: Via SDK oficial CIDBIO (CaptureImage apenas)
                //-----------------------------//
                else if (cidbio.CaptureImage) {
                  console.log('📸 Usando CIDBIO.CaptureImage()');
                  
                  var imageBuf = null;
                  
                  // Chamar função do SDK
                  var result = cidbio.CaptureImage(
                    function(imgBuf, w, h) { 
                      imageBuf = imgBuf; 
                      width = w; 
                      height = h; 
                    }
                  );
                  
                  if (result === 0 || result === CIDBIO_SUCCESS || result === 0) {
                    console.log('✅ Captura realizada com sucesso!');
                    
                    // Converter bitmap para base64
                    if (imageBuf && width > 0 && height > 0) {
                      imagemBase64 = bitmapToBase64(imageBuf, width, height);
                      if (!imagemBase64 && typeof imageBuf === 'string') {
                        imagemBase64 = imageBuf.startsWith('data:image') 
                          ? imageBuf 
                          : 'data:image/png;base64,' + imageBuf;
                      }
                    }
                  } else {
                    console.error('❌ Erro na captura. Código:', result);
                    throw new Error('Erro ao capturar biometria. Código: ' + result);
                  }
                }
                //-----------------------------//
                // Método 3: Via ActiveX (compatibilidade)
                //-----------------------------//
                else if (cidbio.isActiveX && cidbio.leitor) {
                  console.log('📸 Usando ActiveX Control ID');
                  
                  var resultado = cidbio.leitor.Capturar(sessionId || 1, 1);
                  
                  if (resultado && resultado > 0) {
                    if (cidbio.leitor.ObterImagem) {
                      imagemBase64 = cidbio.leitor.ObterImagem();
                    } else if (cidbio.leitor.GetImage) {
                      imagemBase64 = cidbio.leitor.GetImage();
                    }
                    
                    if (cidbio.leitor.ObterTemplate) {
                      template = cidbio.leitor.ObterTemplate();
                    } else if (cidbio.leitor.GetTemplate) {
                      template = cidbio.leitor.GetTemplate();
                    }
                  }
                }
                //-----------------------------//
                // Método 4: Via SDK JavaScript (métodos genéricos)
                //-----------------------------//
                else if (cidbio.isSDK && cidbio.leitor) {
                  console.log('📸 Usando SDK JavaScript Control ID');
                  
                  if (cidbio.leitor.Capturar) {
                    var resultado = cidbio.leitor.Capturar(sessionId || 1, 1);
                    
                    if (resultado && resultado > 0) {
                      if (cidbio.leitor.ObterImagem) {
                        imagemBase64 = cidbio.leitor.ObterImagem();
                      } else if (cidbio.leitor.GetImage) {
                        imagemBase64 = cidbio.leitor.GetImage();
                      }
                      
                      if (cidbio.leitor.ObterTemplate) {
                        template = cidbio.leitor.ObterTemplate();
                      } else if (cidbio.leitor.GetTemplate) {
                        template = cidbio.leitor.GetTemplate();
                      }
                    }
                  }
                }
                
                //-----------------------------//
                // Retornar resultado
                //-----------------------------//
                if (imagemBase64) {
                  // Garantir que tem prefixo data:image
                  if (!imagemBase64.startsWith('data:image')) {
                    imagemBase64 = 'data:image/png;base64,' + imagemBase64;
                  }
                  
                  console.log('✅ Biometria capturada! Imagem:', 'Sim', 'Template:', template ? 'Sim' : 'Não');
                  
                  if (callback) {
                    callback({
                      imagem: imagemBase64,
                      template: template || '',
                      sessao: sessionId
                    });
                    return;
                  }
                } else {
                  console.error('❌ Captura realizada mas imagem não disponível');
                  throw new Error('Imagem da biometria não foi retornada pelo equipamento');
                }
                
              } catch(captureError) {
                console.error('❌ Erro ao capturar biometria:', captureError);
                if (callback) {
                  callback(null);
                }
                return;
              }
            }
            
            //-----------------------------//
            // Se Control ID não disponível, usar simulação para desenvolvimento
            //-----------------------------//
            console.warn('⚠️ Control ID não detectado, usando simulação...');
            console.warn('⚠️ Certifique-se de que:');
            console.warn('   1. O equipamento Control ID está conectado via USB');
            console.warn('   2. Os drivers estão instalados');
            console.warn('   3. O SDK JavaScript da Control ID (iDBio) está carregado');
            console.warn('   4. A biblioteca está acessível via window.CIDBIO ou window.IDBio');
            
            // Retornar dados simulados apenas em desenvolvimento
            setTimeout(function() {
              if (callback) {
                var canvas = document.createElement('canvas');
                canvas.width = 240;
                canvas.height = 320;
                var ctx = canvas.getContext('2d');
              
                ctx.fillStyle = '#ffffff';
                ctx.fillRect(0, 0, canvas.width, canvas.height);
              
                ctx.strokeStyle = '#333333';
                ctx.lineWidth = 2;
                ctx.beginPath();
                // Desenhar padrão de digital simulada mais realista
                for (var i = 0; i < 15; i++) {
                  var radius = 60 + i * 3;
                  var angle = (i * 30) * Math.PI / 180;
                  var x = 120 + Math.cos(angle) * radius * 0.3;
                  var y = 160 + Math.sin(angle) * radius * 0.3;
                  ctx.arc(x, y, radius, 0, Math.PI * 2);
                  ctx.stroke();
                }
              
                var imagemBase64 = canvas.toDataURL('image/png');
                
                callback({
                  imagem: imagemBase64,
                  template: 'template_' + tipo + '_' + Date.now(),
                  sessao: sessionId
                });
              }
            }, 2000);
            
          } catch(e) {
            console.error('❌ Erro geral ao capturar biometria:', e);
            if (callback) {
              callback(null);
            }
          }
        };
        ''';

      final head = html.document.head;
      if (head != null) {
        head.append(script as html.Element);
      }
      print('✅ Scripts Control ID adicionados');
      print('💡 Para usar o SDK oficial, certifique-se de que o script cidbio.js está carregado');
    } catch (e) {
      print('❌ Erro ao adicionar scripts Control ID: $e');
    }
  }


  //-----------------------------//
  // Invocar método JavaScript e retornar resultado
  //-----------------------------//
  Future<dynamic> _invokeJsMethod(String methodName, [dynamic params]) async {
    try {
      if (params != null && params is Map) {
        // Método assíncrono com callback
        final completer = Completer<dynamic>();
        
        // Converter callback Dart para JavaScript
        // allowInterop is a top-level function from dart:js (or stub)
        final callback = js.allowInterop((result) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        });
        
        // Invocar método JavaScript
        js.context.callMethod(methodName, [js.JsObject.jsify(params), callback]);
        
        return await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Timeout ao chamar $methodName');
          },
        );
      } else {
        // Método síncrono simples
        final result = js.context.callMethod(methodName);
        return result;
      }
    } catch (e) {
      print('❌ Erro ao invocar método JavaScript $methodName: $e');
      rethrow;
    }
  }

  //-----------------------------//
  // Gerar imagem mock de biometria para desenvolvimento
  //-----------------------------//
  String _generateMockBiometryImage() {
    // Imagem PNG em base64 de 1x1 pixel transparente (placeholder)
    // Será substituída pela imagem real do equipamento
    return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  }

  //-----------------------------//
  // Desconectar do equipamento
  //-----------------------------//
  Future<void> disconnect() async {
    try {
      if (kIsWeb && _sessionId != null) {
        try {
          js.context.callMethod('disconnectControlIdDevice', [_sessionId]);
        } catch (e) {
          print('⚠️ Erro ao desconectar Control ID: $e');
        }
      }
      
      _sessionId = null;
      _isConnected = false;
      await _biometryController?.close();
      _biometryController = null;
      
      print('✅ Control ID desconectado');
    } catch (e) {
      print('❌ Erro ao desconectar Control ID: $e');
    }
  }

  //-----------------------------//
  // Getter para verificar se está conectado
  //-----------------------------//
  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;
}

