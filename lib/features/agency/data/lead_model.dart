/// Lead type + status enum. Mirrors the web's `Lead` interface in
/// `foxy_ads_web/src/lib/leads.ts`. The agency dashboard inbox (Task 7)
/// and lead-detail sheet (Task 12) consume this.
const List<String> LEAD_STATUSES = ['new', 'contacted', 'closed'];

class Lead {
  final String id;
  final String listingTitle;
  final String ownerUserId;
  final String buyerName;
  final String buyerEmail;
  final String message;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? listingId;
  final String? developmentId;
  final String? buyerUserId;
  final String? buyerPhone;
  final String? notes;

  const Lead({
    required this.id,
    required this.listingTitle,
    required this.ownerUserId,
    required this.buyerName,
    required this.buyerEmail,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.listingId,
    this.developmentId,
    this.buyerUserId,
    this.buyerPhone,
    this.notes,
  });

  /// Maps the row shape returned by Supabase / the `leads` RPC. Tolerates
  /// nullable joined fields (`listing_title`, `owner_user_id`, `buyer_*`)
  /// because some list queries return them as empty when the join misses.
  factory Lead.fromRow(Map<String, dynamic> r) => Lead(
        id: r['id'] as String? ?? '',
        listingId: r['listing_id'] as String?,
        developmentId: r['development_id'] as String?,
        listingTitle: (r['listing_title'] ?? '') as String,
        ownerUserId: (r['owner_user_id'] ?? '') as String,
        buyerUserId: r['buyer_user_id'] as String?,
        buyerName: (r['buyer_name'] ?? '') as String,
        buyerEmail: (r['buyer_email'] ?? '') as String,
        buyerPhone: r['buyer_phone'] as String?,
        message: (r['message'] ?? '') as String,
        status: (r['status'] ?? 'new') as String,
        notes: r['notes'] as String?,
        createdAt: (r['created_at'] ?? '') as String,
        updatedAt: (r['updated_at'] ?? '') as String,
      );
}
