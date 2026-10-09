import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_response.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/responsive/responsive_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patient/data/models/patient_models.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../data/account_portal_data.dart';
import '../providers/account_portal_provider.dart';

enum AccountSection {
  insurance('Insurance', Icons.shield_outlined),
  documents('Documents', Icons.folder_outlined),
  billing('Billing', Icons.credit_card_rounded);

  const AccountSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AccountPortalScreen extends ConsumerStatefulWidget {
  const AccountPortalScreen({
    super.key,
    this.initialSection = AccountSection.insurance,
  });
  final AccountSection initialSection;

  @override
  ConsumerState<AccountPortalScreen> createState() =>
      _AccountPortalScreenState();
}

class _AccountPortalScreenState extends ConsumerState<AccountPortalScreen> {
  AccountSection get _section => widget.initialSection;
  final _photos = <String, SelectedAccountPhoto>{};
  String? _picking;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto(String type) async {
    if (_picking != null) return;
    setState(() => _picking = type);
    try {
      final photo = await ref.read(accountPhotoPickerProvider).pick();
      if (mounted && photo != null) setState(() => _photos[type] = photo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'Could not open your photo library. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = null);
    }
  }

  void _contact(String title, String message, {String topic = 'general'}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ClinicRequestSheet(
        title: title,
        initialMessage: message,
        topic: topic,
      ),
    );
  }

  Future<void> _openDocument(AccountDocument document) async {
    final uri = Uri.tryParse(resolveMediaUrl(document.url));
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        document.url.isEmpty) {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountPortalProvider);
    final user = ref.watch(authProvider).user;
    final responsive = context.responsive;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_section.label)),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 820,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(formsProvider);
              ref.invalidate(appointmentsProvider);
              ref.invalidate(accountPortalProvider);
              try {
                await ref.read(accountPortalProvider.future);
              } catch (_) {
                // The account error card displays the failed refresh.
              }
            },
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: responsive.pagePadding.copyWith(top: 8, bottom: 36),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.navyCard],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 25,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Your account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              switch (_section) {
                                AccountSection.insurance =>
                                  'Your coverage & insurance cards',
                                AccountSection.documents =>
                                  'Your photo ID & consent forms',
                                AccountSection.billing =>
                                  'Your balance & payment history',
                              },
                              style: const TextStyle(
                                color: AppColors.textOnDarkMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (account.isLoading) const LinearProgressIndicator(),
                if (account.hasError) ...[
                  _PortalCard(
                    title: 'Account details unavailable',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'We could not load your account details. Please try again.',
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(accountPortalProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...switch (_section) {
                  AccountSection.insurance => _insurance(
                    account.asData?.value,
                    loaded: account.hasValue,
                  ),
                  AccountSection.documents => _documents(account.asData?.value),
                  AccountSection.billing => _billing(
                    account.asData?.value,
                    loaded: account.hasValue,
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _insurance(AccountPortalData? data, {required bool loaded}) => [
    _PortalCard(
      title: 'Primary Insurance',
      action: TextButton(
        onPressed: () => _contact(
          'Update insurance',
          'I would like to update my primary insurance. Please let me know how to submit my policy details.',
        ),
        child: const Text('Update'),
      ),
      child: data?.primary != null
          ? _InsuranceDetails(plan: data!.primary!)
          : _PortalEmpty(
              icon: Icons.shield_outlined,
              title: loaded
                  ? 'No primary insurance details available'
                  : 'Coverage details are not available yet',
              subtitle: 'Contact the front office to confirm your coverage.',
            ),
    ),
    const SizedBox(height: 16),
    _PortalCard(
      title: 'Insurance Card',
      subtitle: 'Choose a clear photo of the front of your current card.',
      child: _photoTile('insurance_card', 'Insurance Card (Front)', data),
    ),
    const SizedBox(height: 16),
    _PortalCard(
      title: 'Secondary Insurance',
      action: TextButton.icon(
        onPressed: () => _contact(
          'Secondary insurance',
          'I would like to add or update my secondary insurance. Please help me provide the plan details.',
        ),
        icon: const Icon(Icons.add, size: 16),
        label: Text(data?.secondary == null ? 'Add' : 'Update'),
      ),
      child: data?.secondary != null
          ? _InsuranceDetails(plan: data!.secondary!)
          : _PortalEmpty(
              icon: Icons.shield_outlined,
              title: loaded
                  ? 'No secondary insurance details available'
                  : 'Secondary coverage is not available yet',
              subtitle: 'Have another plan? Ask the front office to add it.',
            ),
    ),
    const SizedBox(height: 16),
    const _PortalNotice(
      'Your clinic confirms eligibility and benefits. Contact the front office with coverage questions.',
    ),
  ];

  Widget _photoTile(String type, String label, AccountPortalData? data) {
    final matches =
        data?.documents.where((document) => document.type == type).toList() ??
        [];
    final document = matches.isNotEmpty ? matches.first : null;
    final photo = _photos[type];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (document != null) ...[
            Text('On file: ${document.name}'),
            if (document.status.isNotEmpty)
              Text(
                'Status: ${document.status}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (document.url.isNotEmpty)
              TextButton(
                onPressed: () => _openDocument(document),
                child: const Text('View document'),
              ),
          ],
          if (photo != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                photo.bytes,
                height: 130,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 60,
                  child: Center(child: Text('Preview unavailable')),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(photo.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text(
              'Selected for preview • not submitted',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
            ),
            TextButton(
              onPressed: () => setState(() => _photos.remove(type)),
              child: const Text('Remove photo'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: _picking == null ? () => _choosePhoto(type) : null,
            icon: _picking == type
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(photo == null ? 'Choose photo' : 'Replace photo'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photos stay in this preview. Ask the clinic how to submit them.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _documents(AccountPortalData? data) {
    final forms = ref.watch(formsProvider);
    return [
      _PortalCard(
        title: 'Photo ID',
        subtitle: 'Choose clear photos of your government-issued ID.',
        child: LayoutBuilder(
          builder: (_, constraints) {
            final front = _photoTile('id_front', 'Photo ID (Front)', data);
            final back = _photoTile('id_back', 'Photo ID (Back)', data);
            return constraints.maxWidth >= 520
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: front),
                      const SizedBox(width: 12),
                      Expanded(child: back),
                    ],
                  )
                : Column(children: [front, const SizedBox(height: 12), back]);
          },
        ),
      ),
      const SizedBox(height: 16),
      _PortalCard(
        title: 'Consent Forms',
        subtitle: 'Forms and consent status shared by your clinic.',
        child: forms.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not load your consent forms.'),
              TextButton(
                onPressed: () => ref.invalidate(formsProvider),
                child: const Text('Retry forms'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? const _PortalEmpty(
                  icon: Icons.description_outlined,
                  title: 'No forms shared yet',
                  subtitle: 'Documents from your clinic will appear here.',
                )
              : Column(children: [for (final form in items) _consentRow(form)]),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _contact(
          'Document assistance',
          'Please help me submit my ID or insurance card and complete any required consent forms.',
        ),
        icon: const Icon(Icons.support_agent),
        label: const Text('Contact front office'),
      ),
    ];
  }

  Widget _consentRow(PatientFormModel form) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(
          form.isSigned
              ? Icons.check_circle_outline
              : Icons.description_outlined,
          color: form.isSigned
              ? const Color(0xFF059669)
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                form.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                form.isSigned && form.signedAt.isNotEmpty
                    ? 'Signed ${_date(form.signedAt)}'
                    : _status(form.status),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(form.title),
              content: SingleChildScrollView(
                child: Text(
                  [
                    'Status: ${_status(form.status)}',
                    if (form.signedAt.isNotEmpty)
                      'Signed: ${_date(form.signedAt)}',
                    if (form.dueAt.isNotEmpty) 'Due: ${_date(form.dueAt)}',
                    if (form.description.isNotEmpty) form.description,
                    if (!form.isSigned)
                      'Contact the front office to complete this form.',
                  ].join('\n\n'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: const Text('View'),
        ),
      ],
    ),
  );

  List<Widget> _billing(AccountPortalData? data, {required bool loaded}) {
    final billing = data?.billing ?? const BillingSummary();
    final balance = billing.balanceDue;
    final appointments = ref.watch(appointmentsProvider);
    final color = balance == null
        ? AppColors.primary
        : balance > 0
        ? const Color(0xFFDC2626)
        : const Color(0xFF059669);
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Balance',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              balance == null ? 'Not available' : _money(balance),
              style: TextStyle(
                color: color,
                fontSize: balance == null ? 28 : 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              balance == null
                  ? 'Ask your clinic for your current statement.'
                  : balance > 0
                  ? 'Contact billing for payment options.'
                  : 'Your account is current — no payment due',
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _contact(
                'Billing assistance',
                balance != null && balance > 0
                    ? 'I would like to pay my balance. Please send me the secure payment options.'
                    : 'I have a question about my balance or billing statement.',
                topic: 'billing',
              ),
              icon: const Icon(Icons.credit_card_rounded, size: 18),
              label: Text(
                balance != null && balance > 0
                    ? 'Request payment options'
                    : 'Contact billing',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _PortalCard(
        title: 'Upcoming Visit',
        child: appointments.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not load your upcoming visit.'),
              TextButton(
                onPressed: () => ref.invalidate(appointmentsProvider),
                child: const Text('Retry visit'),
              ),
            ],
          ),
          data: (items) {
            final upcoming = items
                .where(
                  (item) =>
                      !const {
                        'cancelled',
                        'canceled',
                        'completed',
                        'no_show',
                        'no-show',
                      }.contains(item.status.toLowerCase()) &&
                      (item.sortDateTime == null ||
                          (item.endDateTime ?? item.sortDateTime!).isAfter(
                            DateTime.now(),
                          )),
                )
                .toList();
            if (upcoming.isEmpty) {
              return const _PortalEmpty(
                icon: Icons.calendar_today_outlined,
                title: 'No upcoming visits',
                subtitle: 'Your next scheduled visit will appear here.',
              );
            }
            upcoming.sort(
              (a, b) => (a.sortDateTime ?? DateTime(9999)).compareTo(
                b.sortDateTime ?? DateTime(9999),
              ),
            );
            final visit = upcoming.first;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
              ),
              title: Text(visit.title),
              subtitle: Text(
                '${visit.dateLabel} • ${visit.timeLabel}\nExpected copay: ${billing.nextCopay == null ? (data?.primary?.copay.isNotEmpty == true ? data!.primary!.copay : 'Confirm with clinic') : _money(billing.nextCopay!)}',
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      _PortalCard(
        title: 'Payment Method',
        action: TextButton(
          onPressed: () => _contact(
            'Payment method',
            'I would like to update my payment method. Please send me a secure way to do this.',
            topic: 'billing',
          ),
          child: const Text('Update'),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                billing.paymentMethod.isEmpty
                    ? 'Contact billing to confirm your payment method.'
                    : billing.paymentMethod,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _PortalCard(
        title: 'Payment History',
        child: billing.history.isEmpty
            ? _PortalEmpty(
                icon: Icons.receipt_long_outlined,
                title: loaded
                    ? 'No payment history available'
                    : 'Payment history is not available yet',
                subtitle: 'Request a statement from your billing team.',
              )
            : Column(
                children: [
                  for (final entry in billing.history)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [_date(entry.date), entry.payer]
                                      .where((value) => value.isNotEmpty)
                                      .join(' • '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                entry.amount == null
                                    ? '—'
                                    : _money(entry.amount!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (entry.status.isNotEmpty)
                                Text(
                                  _status(entry.status),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      const _PortalNotice(
        'Use the secure payment options provided by your clinic. Do not send card numbers in messages.',
      ),
    ];
  }
}

String _money(double value) =>
    NumberFormat.currency(locale: 'en_US', symbol: '\$').format(value);
String _date(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat.yMMMd().format(date);
}

String _status(String value) => value.isEmpty
    ? 'Not provided'
    : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';

class _InsuranceDetails extends StatelessWidget {
  const _InsuranceDetails({required this.plan});
  final InsurancePlan plan;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        plan.carrier.isEmpty ? 'Carrier not provided' : plan.carrier,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Chip(
        label: Text(
          plan.status.isEmpty
              ? 'Verification not provided'
              : _status(plan.status),
        ),
        avatar: const Icon(Icons.shield_outlined, size: 16),
        backgroundColor: AppColors.primaryWash,
        side: BorderSide.none,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 20,
        runSpacing: 16,
        children: [
          for (final field in {
            'Member ID': plan.memberId,
            'Group #': plan.groupNumber,
            'Copay': plan.copay,
            'Deductible': plan.deductible,
          }.entries)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.key,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    field.value.isEmpty ? 'Not provided' : field.value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (plan.lastVerified.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          'Last verified: ${_date(plan.lastVerified)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    ],
  );
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?action,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _PortalEmpty extends StatelessWidget {
  const _PortalEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PortalNotice extends StatelessWidget {
  const _PortalNotice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}

class _ClinicRequestSheet extends ConsumerStatefulWidget {
  const _ClinicRequestSheet({
    required this.title,
    required this.initialMessage,
    required this.topic,
  });
  final String title, initialMessage, topic;
  @override
  ConsumerState<_ClinicRequestSheet> createState() =>
      _ClinicRequestSheetState();
}

class _ClinicRequestSheetState extends ConsumerState<_ClinicRequestSheet> {
  late final _message = TextEditingController(text: widget.initialMessage);
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(patientRepositoryProvider)
          .createConversation(topic: widget.topic, message: message);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      ref.invalidate(dashboardProvider);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your message was sent. Find the conversation in Messages.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Message not sent. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a message to your clinic. Photos and payment details are not attached.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 5,
            maxLength: 1500,
            enabled: !_sending,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.badge),
              ),
            ),
          Row(
            children: [
              TextButton(
                onPressed: _sending ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send message'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
