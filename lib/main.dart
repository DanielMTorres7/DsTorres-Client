import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para converter o corpo da requisição em JSON

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SocketIoExample(),
    );
  }
}

class SocketIoExample extends StatefulWidget {
  const SocketIoExample({super.key});

  @override
  _SocketIoExampleState createState() => _SocketIoExampleState();
}

class _SocketIoExampleState extends State<SocketIoExample> {
  late IO.Socket socket;
  Map<String, Map<String, dynamic>> chats = {};
  String? selectedUserId;
  String? selectedChatUId;
  List<Map<String, dynamic>> selectedMessages = [];
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool hasControl = false; // Variável para rastrear se o controle foi assumido

  @override
  void initState() {
    super.initState();
    // Inicializa a conexão Socket.IO
    socket = IO.io('http://localhost:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    // Conectar ao servidor
    socket.connect();

    // Evento de conexão estabelecida
    socket.on('connect', (_) {
      print('Conectado');
      socket.emit("managerConnection", {"empresa": "ganep", "manager": 'manager'});
    });

    // Receber o evento 'updateChat'
    socket.on('updateChat', (data) {
      print('Dados recebidos: $data'); // Adicione esta linha para depuração

      if (data is Map<String, dynamic>) {
        final chatsData = data['chats'] as Map<String, dynamic>? ?? {};
        setState(() {
          chats = chatsData.map((uid, chatInfo) {
            final chatMap = chatInfo as Map<String, dynamic>;
            return MapEntry(uid, chatMap);
          });

          // Se o usuário selecionado já estiver disponível no novo chatData, atualize as mensagens
          if (selectedUserId != null) {
            final userChat = chats[selectedUserId];
            if (userChat != null) {
              final messageHistory = userChat['MessageHistory'] as Map<String, dynamic>?;
              selectedMessages = messageHistory?.values.map((msg) {
                return {
                  'sender': msg['sender'],
                  'text': msg['message']['text'],
                  'status': msg['message']['status'],
                  'sent': msg['status']['sent'],
                };
              }).toList() ?? [];
            }
          }
        });
      } else {
        print('Dados recebidos não são um Map: $data');
      }
    });

    // Evento de desconexão
    socket.on('disconnect', (_) {
      print('Desconectado');
    });
  }

  @override
  void dispose() {
    // Desconectar ao sair
    socket.disconnect();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (selectedUserId == null || _messageController.text.isEmpty) return;

    final userChat = chats[selectedUserId];
    if (userChat == null) return;

    final phone = userChat['User']['phone'] as String? ?? '';
    final name = userChat['User']['name'] as String? ?? '';
    final message = _messageController.text;

    try {
      final response = await http.post(
        Uri.parse('http://whatsapp.dstorres.com.br/ganep/webhook'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'message': message,
          'phone': phone,
          'name': name,
        }),
      );

      if (response.statusCode == 200) {
        print('Mensagem enviada com sucesso!');
        _messageController.clear();
      } else {
        print('Falha ao enviar mensagem. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao enviar mensagem: $e');
    }
  }
  Future<void> _answerMessage() async {
    if (selectedUserId == null || _answerController.text.isEmpty) return;

    final userChat = chats[selectedUserId];
    if (userChat == null) return;

    final phone = userChat['User']['phone'] as String? ?? '';
    final message = _answerController.text;

    try {
      final response = await http.post(
        Uri.parse('http://whatsapp.dstorres.com.br/ganep/webhook/answer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'message': message,
          'chatUid': phone,
          'manager': 'manager',
        }),
      );

      if (response.statusCode == 200) {
        print('Mensagem enviada com sucesso!');
        _answerController.clear();
      } else {
        print('Falha ao enviar mensagem. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao enviar mensagem: $e');
    }
  }

  Future<void> _endChat() async {
    if (selectedUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://whatsapp.dstorres.com.br/ganep/webhook/endchat'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'chatUid': selectedUserId,
        }),
      );

      if (response.statusCode == 200) {
        print('Chat finalizado com sucesso!');
        setState(() {
          // Limpar mensagens e usuário selecionado
          selectedMessages.clear();
          selectedUserId = null;
          hasControl = false; // Resetar controle
        });
      } else {
        print('Falha ao finalizar o chat. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao finalizar o chat: $e');
    }
  }

  Future<void> _takeControl() async {
    if (selectedUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://whatsapp.dstorres.com.br/ganep/webhook/exitprotocol'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'chatUid': selectedUserId,
          'manager': 'manager',
        }),
      );

      if (response.statusCode == 200) {
        print('Controle do chat assumido com sucesso!');
        setState(() {
          hasControl = true; // Atualiza o estado para indicar que o controle foi assumido
        });
      } else {
        print('Falha ao assumir o controle do chat. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao assumir o controle do chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Lateral com Chats')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: chats.entries.map((entry) {
            final uid = entry.key;
            final chatInfo = entry.value;
            final user = chatInfo['User'] as Map<String, dynamic>?;
            final userName = user?['name'] ?? 'Nome não disponível';
            return ListTile(
              title: Text(userName),
              onTap: () {
                setState(() {
                  selectedUserId = uid;
                  selectedChatUId = entry.key;
                  print('Chat selecionado: $selectedChatUId');
                  final userChat = chats[uid];
                  if (userChat != null) {
                    final messageHistory = userChat['MessageHistory'] as Map<String, dynamic>?;
                    selectedMessages = messageHistory?.values.map((msg) {
                      return {
                        'sender': msg['sender'],
                        'text': msg['message']['text'],
                        'status': msg['message']['status'],
                        'sent': msg['status']['sent'],
                      };
                    }).toList() ?? [];
                  }
                  hasControl = false; // Resetar controle ao selecionar um novo chat
                });
                Navigator.pop(context); // Fecha o Drawer
              },
            );
          }).toList(),
        ),
      ),
      body: selectedUserId == null
          ? Center(child: Text('Selecione um usuário'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedMessages.length,
                    itemBuilder: (context, index) {
                      final message = selectedMessages[index];
                      return ListTile(
                        title: Text(message['sender']),
                        subtitle: Text(message['text']),
                        trailing: Text(message['status']),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Digite uma mensagem',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage, // Enviar a mensagem via HTTP POST
                      )
                    ],
                ),
                if (hasControl) ...[
                  Row(
                    
                    children: 
                    [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Digite uma resposta',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _answerMessage, // Enviar a mensagem via HTTP POST
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: _endChat, // Finalizar o chat via HTTP POST
                    ),
                  ]
                    
                  ),
                ],
                if (!hasControl)
                  ElevatedButton(
                    onPressed: _takeControl, // Assumir controle do chat via HTTP POST
                    child: const Text('Assumir Controle'),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Usuário selecionado: ${chats[selectedUserId]?['User']?['name'] ?? 'Desconhecido'}'),
                ),
              ],
            ),
    );
  }
}