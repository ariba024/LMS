import '../../data/models/ticket.dart';
import 'api_client.dart';

class TicketService {
  static Future<List<Ticket>> listTickets() async {
    final resp = await apiClient.get('/api/v1/tickets');
    final data = resp.data as List;
    return data.map((j) => Ticket.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<Ticket> getTicket(String id) async {
    final resp = await apiClient.get('/api/v1/tickets/$id');
    return Ticket.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Ticket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String description,
  }) async {
    final resp = await apiClient.post('/api/v1/tickets', data: {
      'subject':     subject,
      'category':    category,
      'priority':    priority,
      'description': description,
    });
    return Ticket.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Ticket> updateStatus(String id, String status) async {
    final resp = await apiClient.patch('/api/v1/tickets/$id', data: {'status': status});
    return Ticket.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Ticket> addReply(String id, String body) async {
    final resp = await apiClient.post('/api/v1/tickets/$id/replies', data: {'body': body});
    return Ticket.fromJson(resp.data as Map<String, dynamic>);
  }
}
