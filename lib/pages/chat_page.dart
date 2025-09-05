import 'dart:async';
import 'dart:convert';

import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../functions/ui.dart';
import '../multiplat_ui.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'settings_page.dart';


class ChatPageRoute extends StatelessWidget {
  const ChatPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: w.appBar(
        context: context,
        title: 'Flow by Spooky Services',
        backgroundColor: uf.cLD(
          context: context,
          color: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.onPrimary,
          ],
        ), // Add background color to the app bar
        foregroundColor: Colors.white.withValues(
          alpha: 0.9,
        ), // Add foreground color to the app bar
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: w.iconButton(
              context: context,
              icon: Icons.settings, // Change icon based on selected index
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPageRoute()),
                );
              },
              color: Colors.white.withValues(alpha: 0.9), // Set icon color
            ),
          ),
        ],
      ),
      body: ChatPage(), // Use the SettingsPage widget
    );
  }
}

Future<bool> sendReply(String message) async {
  if (message.replaceAll(" ", "") == "") {
    return false;
  }

  final url = Uri.parse('https://flow.spookysrv.com/reply');
  final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
  String? device = await sp.getString("convoToken");
  final body = {'device': device, 'message': message};

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 418) {
    print('Success');
    return true;
  } else {
    print('Error: ${response.statusCode} ${response.body}');
    return false;
  }
}

Future<String> _getMessagesRequest() async {
  print("Sending request");
  final convoToken = await sp.getString("convoToken");
  final response = await http.get(
    Uri.parse('https://flow.spookysrv.com/viewframe/?cid=$convoToken'),
    headers: {'Content-Type': 'application/json'},
  );
  sp.setStringSync("messageJson", response.body);
  // print(response.body);
  return response.body;
}

Future<List<ChatMessage>> _getMessages({String? messageData}) async {
  messageData ??= await _getMessagesRequest();
  List<dynamic> jsonData = json.decode(messageData);
  List<ChatMessage> messages = jsonData
      .map(
        (item) => ChatMessage(
          usr: item['usr'],
          msg: "${item['msg']}", // Fix if the message is not a string (all numbers)
          date: item['date'],
          device: item['device'],
        ),
      )
      .toList();
  return messages;
}

Map<String, List<ChatMessage>> _groupMessagesByDate(
  List<ChatMessage> messages,
) {
  Map<String, List<ChatMessage>> groupedMessages = {};

  for (ChatMessage message in messages) {
    String dateKey = DateFormat('yyyy-MM-dd').format(message.dateTime);
    groupedMessages.putIfAbsent(dateKey, () => []).add(message);
  }

  return groupedMessages;
}

Future<List<Widget>> _buildChatWidgets({
  required BuildContext context,
  String? messageData,
}) async {
  List<Widget> widgets = [];
  final Map<String, List<ChatMessage>> groupedMessages = _groupMessagesByDate( ///
    await _getMessages(messageData: messageData),
  );
  final String? convoId = await sp.getString("convoToken");
  final theme = Theme.of(context);
  // For each date group
  groupedMessages.forEach((dateKey, messagesForDate) {
    // Add a DateChip at the start of each date group
    widgets.add(
      DateChip(date: DateTime.parse(dateKey), color: Colors.transparent),
    );

    // Add chat bubbles for all messages on that date
    for (var message in messagesForDate) {
      bool isSender = message.device == convoId;
      widgets.add(
        w.chatBubble(
          context: context,
          text: message.msg,
          color: isSender
              ? uf.cLD(
                  context: context,
                  color: [
                    theme.colorScheme.primary,
                    theme.colorScheme.onPrimary,
                  ],
                )
              : uf.cLD(
                  context: context,
                  color: [
                    theme.colorScheme.secondary,  
                    theme.colorScheme.onSecondary,
                  ],
                ),
          tail: false,
          isSender: isSender,
          textStyle: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
  });

  return widgets;
}

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<List<Widget>>? _futureResult;

  @override
  void dispose() {
    _textEditingController
        .dispose(); // Dispose controller when widget is removed
    super.dispose();
  }

  void _loadChat({String? messageData}) {
    _futureResult = _buildChatWidgets(
      context: context,
      messageData: messageData,
    );
  }

  void _reloadChat({String? messageData}) {
    if (!context.mounted) {return;}
    setState(() {
      _loadChat(messageData: messageData);
    });
  }

  Future<void> _periodRecheckChat() async {
    String? currentMessages = await sp.getString("messageJson");
    String newMessages = await _getMessagesRequest();
    if (newMessages != currentMessages) {
      _reloadChat(messageData: newMessages);
    }
  }

  @override
  void initState() {
    _loadChat();
    Timer.periodic(Duration(seconds: 7), (Timer timer) {
      _periodRecheckChat();
      print('Function executed at ${DateTime.now()}');
    });
    super.initState();
  }

  void _scrollToBottom({int? ms}) {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        position,
        duration: Duration(milliseconds: ms ?? 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool firstTime = true;

  FutureBuilder<List<Widget>?> _chatBubblesBuilder({
    required Widget Function(List<Widget> value) builder,
    required BuildContext context,
  }) {
    return FutureBuilder<List<Widget>?>(
      future: _futureResult,
      builder: (BuildContext context, AsyncSnapshot<List<Widget>?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Center(child: w.loadingIcon(context: context)),
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          bool smoothScroll = false;
          if (firstTime) {
            smoothScroll = true;
          }
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(ms: smoothScroll ? 500 : 1),
          );
          firstTime = false;
          return builder(snapshot.data ?? [Text("Error")]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // var appState = context.watch<MyAppState>();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: _chatBubblesBuilder(
              builder: (res) => Column(children: res),
              context: context,
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.only(
            top: 5,
            left: 8,
            right: 8,
            bottom: MediaQuery.of(context).padding.bottom + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: w.textField(
                    onSubmitted: (value) async {
                      // Action to perform when Enter key is pressed
                      bool res = await sendReply(value);
                      if (res) {
                        _textEditingController.clear();
                        _reloadChat();
                      }
                    },
                    context: context,
                    controller: _textEditingController,
                    borderRadius: BorderRadius.circular(30.0),
                    hintText: 'Type anything...',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: w.iconButton(
                    context: context,
                    icon: Icons.send, // Required: The icon to display
                    onPressed: () async {
                      String currentText = _textEditingController.text;
                      bool res = await sendReply(currentText);
                      if (res) {
                        _textEditingController.clear();
                        _reloadChat();
                      }
                    },
                    tooltip: 'Send', // Optional: A tooltip for accessibility
                    iconSize: 20.0, // Optional: Adjust the size of the icon
                    color: theme
                        .colorScheme
                        .onPrimary, // Optional: Set the color of the icon
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatMessage {
  final String usr; // User who sent the message
  final String msg; // The decoded message text
  final int date; // Unix timestamp (e.g., seconds since epoch)
  final String device; // Device or sender identifier

  ChatMessage({
    required this.usr,
    required this.msg,
    required this.date,
    required this.device,
  });

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(date * 1000).toLocal();

  // Factory constructor to create ChatMessage from JSON, decoding base64 message
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      usr: json['usr'],
      msg: (json['msg']),
      date: json['date'],
      device: json['device'],
    );
  }
}
