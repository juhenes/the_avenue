import '../models/announcement.dart';

abstract class AnnouncementRepository {
  Future<List<Announcement>> fetchAnnouncements({required bool includeArchived});
  Stream<List<Announcement>> watchAnnouncements({required bool includeArchived});
  Future<void> saveAnnouncement(Announcement announcement);
  Future<void> deleteAnnouncement(String id);
}

class DemoAnnouncementRepository implements AnnouncementRepository {
  DemoAnnouncementRepository()
      : _announcements = [
          Announcement(
            id: 'ann-1',
            title: 'Welcome to The Avenue',
            description: 'Announcements appear here first, with pinned and high-priority items shown at the top.',
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            priority: 10,
            author: 'System',
            pinned: true,
          ),
          Announcement(
            id: 'ann-2',
            title: 'Reminder engine ready',
            description: 'Local scheduling is wired as a service so future reminder rules can be synchronized from Firestore.',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            priority: 5,
            author: 'Product Team',
          ),
        ];

  final List<Announcement> _announcements;

  @override
  Future<List<Announcement>> fetchAnnouncements({required bool includeArchived}) async {
    return [..._announcements]
      ..sort((left, right) {
        final priorityComparison = right.priority.compareTo(left.priority);
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        if (left.pinned != right.pinned) {
          return left.pinned ? -1 : 1;
        }
        return right.createdAt.compareTo(left.createdAt);
      });
  }

  @override
  Stream<List<Announcement>> watchAnnouncements({required bool includeArchived}) async* {
    yield await fetchAnnouncements(includeArchived: includeArchived);
  }

  @override
  Future<void> saveAnnouncement(Announcement announcement) async {
    final index = _announcements.indexWhere((existing) => existing.id == announcement.id);

    if (index == -1) {
      _announcements.add(announcement);
    } else {
      _announcements[index] = announcement;
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    _announcements.removeWhere((announcement) => announcement.id == id);
  }
}
