import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';
import 'package:talk_messenger/Screens/SelectContact.dart';
import 'package:talk_messenger/Screens/StatusScreen.dart';
import 'package:talk_messenger/Screens/ProfileSetupScreen.dart';
import 'package:talk_messenger/Screens/ChatSettingsScreen.dart';
import 'package:talk_messenger/Screens/ContactsScreen.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// ─── Cores do novo tema gradiente (roxo) ────────────────────────────────
class _TalkColors {
  static const Color gradientStart = Color(0xFF8A5CF5);
  static const Color gradientEnd = Color(0xFF6539E8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Wrapper para manter páginas externas vivas ──────────────────────────
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── Página de Chats (com keep‑alive e ValueNotifier) ──────────────────
class _ChatsPage extends StatefulWidget {
  final ValueNotifier<List<ChatModel>> conversationsNotifier;
  final ValueNotifier<bool> loadingNotifier;
  final void Function(ChatModel) onTap;
  final void Function(ChatModel) onLongPress;
  final VoidCallback onNewChat;

  const _ChatsPage({
    Key? key,
    required this.conversationsNotifier,
    required this.loadingNotifier,
    required this.onTap,
    required this.onLongPress,
    required this.onNewChat,
  }) : super(key: key);

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<_ChatsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Filtro visual apenas (lógica real vem depois)
  int _selectedFilter = 0;
  final List<String> _filters = const ['Todos', 'Não lidos', 'Grupos', 'Favoritos'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.loadingNotifier,
              builder: (context, loading, _) {
                if (loading) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _TalkColors.gradientEnd),
                  );
                }
                return ValueListenableBuilder<List<ChatModel>>(
                  valueListenable: widget.conversationsNotifier,
                  builder: (context, conversations, _) {
                    if (conversations.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma conversa ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final chat = conversations[index];
                        return _buildChatItem(chat);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: _TalkColors.brandGradient,
        ),
        child: FloatingActionButton(
          onPressed: widget.onNewChat,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_comment_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? _TalkColors.brandGradient : null,
                color: isSelected ? null : const Color(0xFFF0F0F2),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _filters[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF555558),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    return InkWell(
      onTap: () => widget.onTap(chat),
      onLongPress: () => widget.onLongPress(chat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage:
                  chat.avatar != null ? NetworkImage(chat.avatar!) : null,
              child: chat.avatar == null
                  ? Text(
                      chat.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111)),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                            fontSize: 12,
                            color: chat.unreadCount > 0
                                ? _TalkColors.gradientEnd
                                : Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              fontFamily: 'sans-serif', // garante suporte a emojis
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: _TalkColors.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 16, thickness: 0.5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Página de Perfil (com keep‑alive e ValueNotifier) ──────────────────
class _ProfilePage extends StatefulWidget {
  final ValueNotifier<String> nameNotifier;
  final ValueNotifier<String?> avatarNotifier;
  final ValueNotifier<bool> uploadingNotifier;
  final VoidCallback onAvatarTap;
  final VoidCallback onSignOut;

  const _ProfilePage({
    Key? key,
    required this.nameNotifier,
    required this.avatarNotifier,
    required this.uploadingNotifier,
    required this.onAvatarTap,
    required this.onSignOut,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      children: [
        const SizedBox(height: 24),

        // ── Avatar clicável ──
        ValueListenableBuilder<bool>(
          valueListenable: widget.uploadingNotifier,
          builder: (context, uploading, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: widget.avatarNotifier,
              builder: (context, avatarUrl, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: widget.nameNotifier,
                  builder: (context, name, _) {
                    return Center(
                      child: GestureDetector(
                        onTap: uploading ? null : widget.onAvatarTap,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: const Color(0xFFB0BEC5),
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                          fontSize: 40,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            if (uploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            if (!uploading)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    gradient: _TalkColors.brandGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Toque para alterar foto',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: widget.nameNotifier,
          builder: (context, name, _) {
            return Center(
              child: Text(
                name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
            );
          },
        ),
        const SizedBox(height: 28),

        // ── Menu items ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                iconBg: _TalkColors.gradientEnd,
                icon: Icons.person_outline,
                title: 'Conta',
                subtitle: 'Número, Nome de Usuário, Bio',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.chat_bubble_outline,
                title: 'Configurações de Chat',
                subtitle: 'Papel de Parede, Modo Noturno, Animações',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatSettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFF34C759),
                icon: Icons.key_outlined,
                title: 'Privacidade e Segurança',
                subtitle: 'Visto por Último, Dispositivos, Chaves de Acesso',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFFFF3B30),
                icon: Icons.notifications_outlined,
                title: 'Notificações',
                subtitle: 'Sons, Chamadas, Contadores',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.language,
                title: 'Idioma',
                subtitle: 'Português (Brasil)',
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildMenuItem(
            iconBg: const Color(0xFFFF3B30),
            icon: Icons.logout_rounded,
            title: 'Sair',
            subtitle: 'Encerrar sessão',
            titleColor: Colors.red,
            onTap: widget.onSignOut,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMenuItem({
    required Color iconBg,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF111111),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── State principal ──────────────────────────────────────────────────────
class Homescreen extends StatefulWidget {
  const Homescreen({Key? key}) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _currentIndex = 0;

  // ValueNotifiers para compartilhar dados com as páginas
  final ValueNotifier<List<ChatModel>> _conversationsNotifier =
      ValueNotifier<List<ChatModel>>([]);
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String> _profileNameNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> _profileAvatarNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _uploadingAvatarNotifier = ValueNotifier<bool>(false);

  // Instâncias das páginas com keep‑alive
  late final _ChatsPage _chatsPage;
  late final _ProfilePage _profilePage;
  late final Widget _callsPage;
  late final Widget _contactsPage;
  late final Widget _statusPage;

  // Controle de concorrência
  bool _isLoadingConversations = false;

  @override
  void initState() {
    super.initState();

    // Cria as páginas passando os ValueNotifiers
    _chatsPage = _ChatsPage(
      conversationsNotifier: _conversationsNotifier,
      loadingNotifier: _loadingNotifier,
      onTap: _openChat,
      onLongPress: _deleteConversation,
      onNewChat: _openSelectContact,
    );
    _profilePage = _ProfilePage(
      nameNotifier: _profileNameNotifier,
      avatarNotifier: _profileAvatarNotifier,
      uploadingNotifier: _uploadingAvatarNotifier,
      onAvatarTap: _pickAndUploadAvatar,
      onSignOut: _signOut,
    );
    _callsPage = const _KeepAliveWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Calls em breve',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
          ),
        ),
      ),
    );
    _contactsPage = const _KeepAliveWrapper(
      child: ContactsScreen(),
    );
    _statusPage = const _KeepAliveWrapper(
      child: StatusScreen(),
    );

    _loadConversations();
    _subscribeRealtime();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _conversationsNotifier.dispose();
    _loadingNotifier.dispose();
    _profileNameNotifier.dispose();
    _profileAvatarNotifier.dispose();
    _uploadingAvatarNotifier.dispose();
    super.dispose();
  }

  // ── Carregar conversas (com timeout de segurança) ─────────────────────

  Future<void> _loadConversations() async {
    if (_isLoadingConversations) return;
    _isLoadingConversations = true;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _loadingNotifier.value = false;
      _isLoadingConversations = false;
      return;
    }

    try {
      final data = await supabase
          .from('conversation_members')
          .select('''
            conversation_id,
            unread_count,
            conversations (
              id, name, avatar_url, is_group,
              last_message, last_message_time
            )
          ''')
          .eq('user_id', userId)
          .limit(20)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Tempo limite ao carregar conversas (10s)');
            },
          );

      // Ordenação no cliente (já que não temos foreignTable)
      final List<dynamic> sortedData = (data as List).toList()
        ..sort((a, b) {
          final timeA = a['conversations']['last_message_time'] as String? ?? '';
          final timeB = b['conversations']['last_message_time'] as String? ?? '';
          return timeB.compareTo(timeA); // descendente
        });

      final List<ChatModel> newList = sortedData.map((item) {
        final conv = item['conversations'];
        final rawTime = conv['last_message_time'] as String?;
        return ChatModel(
          id: conv['id'],
          name: conv['name'] ?? 'Conversa',
          avatar: conv['avatar_url'],
          isGroup: conv['is_group'] ?? false,
          lastMessage: conv['last_message'] ?? '',
          time: _formatTime(rawTime), // formatado apenas uma vez
          unreadCount: item['unread_count'] ?? 0,
        );
      }).toList();

      _conversationsNotifier.value = newList;
      _loadingNotifier.value = false;
    } catch (e) {
      debugPrint('Erro ao carregar conversas: $e');
      _loadingNotifier.value = false;
    } finally {
      _isLoadingConversations = false;
    }
  }

  /// Força um recarregamento imediato, ignorando a flag de bloqueio.
  void _forceRefresh() {
    _isLoadingConversations = false;
    _loadConversations();
  }

  void _subscribeRealtime() {
    Supabase.instance.client
        .channel('conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _forceRefresh(), // usa o método que ignora bloqueio
        )
        .subscribe();
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();

    if (dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  // ── Perfil ──────────────────────────────────────────────────────────

  Future<void> _loadUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        _profileNameNotifier.value = data['name'] ?? '';
        _profileAvatarNotifier.value = data['avatar_url'];
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    _uploadingAvatarNotifier.value = true;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final path = 'avatars/$userId.$ext';

      await supabase.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase.from('users').upsert({
        'id': userId,
        'avatar_url': url,
      }, onConflict: 'id');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', url);

      if (mounted) {
        _profileAvatarNotifier.value = url;
        _uploadingAvatarNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _uploadingAvatarNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Sign out ────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sair', style: TextStyle(color: Color(0xFF111111))),
        content: const Text('Deseja encerrar a sessão?',
            style: TextStyle(color: Color(0xFF444444))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Deletar conversa ───────────────────────────────────────────────

  Future<void> _deleteConversation(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir conversa',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF111111)),
        ),
        content: Text(
          'Deseja excluir a conversa com "${chat.name}"?\n\nTodas as mensagens serão apagadas para todos.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _TalkColors.gradientEnd),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('messages')
          .delete()
          .eq('conversation_id', chat.id);
      await supabase
          .from('conversation_members')
          .delete()
          .eq('conversation_id', chat.id);
      await supabase
          .from('conversations')
          .delete()
          .eq('id', chat.id);

      _forceRefresh(); // força recarga após exclusão
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Navegação ──────────────────────────────────────────────────────

  void _openChat(ChatModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndividualPage(chatModel: chat),
      ),
    );
  }

  void _openSelectContact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectContact()),
    );
  }

  // ── Build principal ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      _chatsPage,
      _callsPage,
      _contactsPage,
      _statusPage,
      _profilePage,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              _TalkColors.brandGradient.createShader(bounds),
          child: const Text(
            'Talk',
            style: TextStyle(
              color: Colors.white, // sobrescrito pelo ShaderMask
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F0F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search,
                    color: Color(0xFF333333), size: 20),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline,
                  Icons.chat_bubble_rounded, 'Chats'),
              _buildNavItem(
                  1, Icons.call_outlined, Icons.call_rounded, 'Calls'),
              _buildNavItem(2, Icons.people_alt_outlined,
                  Icons.people_alt_rounded, 'Contatos'),
              _buildNavItem(3, Icons.donut_large_outlined,
                  Icons.donut_large_rounded, 'Status'),
              _buildNavItem(4, Icons.person_outline,
                  Icons.person_rounded, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 4) _loadUserProfile();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 32,
              decoration: BoxDecoration(
                gradient: isSelected ? _TalkColors.brandGradient : null,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _TalkColors.gradientEnd : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
