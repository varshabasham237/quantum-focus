import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    final api = context.read<ApiService>();
    final res = await api.get('/notifications/');
    if (res != null && !res.containsKey('error') && res.containsKey('notifications')) {
      final List notifs = res['notifications'];
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _unreadCount = notifs.length;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    final api = context.read<ApiService>();
    await api.patch('/notifications/$id/read', {});
    _fetchNotifications(); // Refresh list
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Alerts & Reminders",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: () async {
                          setModalState(() => _isLoading = true);
                          await _fetchNotifications();
                          setModalState(() => _isLoading = false);
                        },
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_notifications.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("You are all caught up!", style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          Color iconColor = Colors.blueAccent;
                          IconData icon = Icons.info_outline;

                          if (notif['type'] == 'WARNING') {
                            iconColor = Colors.orangeAccent;
                            icon = Icons.warning_amber_rounded;
                          } else if (notif['type'] == 'RESTRICTION_ALERT') {
                            iconColor = Colors.redAccent;
                            icon = Icons.gavel;
                          } else if (notif['type'] == 'MOTIVATION') {
                            iconColor = Colors.greenAccent;
                            icon = Icons.star;
                          }

                          return ListTile(
                            leading: Icon(icon, color: iconColor),
                            title: Text(notif['title'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text(notif['message'], style: const TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await _markAsRead(notif['_id']);
                                setModalState(() {}); // pop UI on refresh
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: _showNotificationPanel,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          )
      ],
    );
  }
}
