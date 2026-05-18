import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/retailer_quote.dart';
import '../../providers/auth_provider.dart';
import '../../services/mpesa_service.dart';
import '../../utils/app_colors.dart';

// ─── Fulfiment mode ─────────────────────────────────────────────────────────
enum _FulfilmentMode { delivery, pickAtStore }

// ─── Payment state ───────────────────────────────────────────────────────────
enum _PayState { idle, loading, success, error }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.retailer,
    required this.subtotal,
    required this.serviceFee,
    required this.grandTotal,
    required this.itemCount,
    required this.householdName,
    this.belowMinimum = false,
  });

  final RetailerInfo retailer;
  final double subtotal;
  final double serviceFee;
  final double grandTotal;
  final int itemCount;
  final String householdName;
  final bool belowMinimum;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  _FulfilmentMode _mode = _FulfilmentMode.delivery;
  _PayState _payState = _PayState.idle;
  String? _errorMsg;

  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill checkout details from the active household profile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final email = auth.currentUser?.email ?? '';
      if (AuthProvider.looksLikePhone(email)) {
        _phoneCtrl.text = email;
      }
      final household = auth.household;
      if (_addressCtrl.text.trim().isEmpty) {
        final addressParts = <String>[];
        final deliveryAddress = household?.deliveryAddress?.trim();
        final supermarketNotes =
            household?.supermarketDeliveryNotes?.trim();
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
          addressParts.add(deliveryAddress);
        }
        if (supermarketNotes != null && supermarketNotes.isNotEmpty) {
          addressParts.add(supermarketNotes);
        }
        if (addressParts.isNotEmpty) {
          _addressCtrl.text = addressParts.join('\n');
        }
      }
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMsg = 'Enter your M-Pesa phone number');
      return;
    }
    if (_mode == _FulfilmentMode.delivery && _addressCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Enter a delivery address');
      return;
    }
    setState(() {
      _payState = _PayState.loading;
      _errorMsg = null;
    });

    final result = await MpesaService.stkPush(
      phone: phone,
      amount: widget.grandTotal,
    );

    if (!mounted) return;
    if (result.success) {
      setState(() => _payState = _PayState.success);
    } else {
      setState(() {
        _payState = _PayState.error;
        _errorMsg = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.retailer.brandColor;
    final brandLight = widget.retailer.brandColorLight;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: _payState == _PayState.success
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    size: 18, color: AppColors.primaryTeal),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Checkout',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryTeal),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.divider),
              ),
            ),
      body: _payState == _PayState.success
          ? _SuccessBody(retailer: widget.retailer, amount: widget.grandTotal)
          : Column(
              children: [
                // ── Fulfilment tabs ───────────────────────────────────────
                _FulfilmentTabs(
                  mode: _mode,
                  brandColor: brand,
                  onChanged: (m) => setState(() {
                    _mode = m;
                    _errorMsg = null;
                  }),
                ),
                // ── Scrollable content ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Delivery address card
                        if (_mode == _FulfilmentMode.delivery) ...[
                          _AddressCard(controller: _addressCtrl),
                          const SizedBox(height: 12),
                        ],
                        // Pick-up info card
                        if (_mode == _FulfilmentMode.pickAtStore) ...[
                          _PickUpCard(retailerName: widget.retailer.name),
                          const SizedBox(height: 12),
                        ],
                        // Order summary card
                        _OrderSummaryCard(
                          retailer: widget.retailer,
                          subtotal: widget.subtotal,
                          serviceFee: widget.serviceFee,
                          grandTotal: widget.grandTotal,
                          itemCount: widget.itemCount,
                          isDelivery: _mode == _FulfilmentMode.delivery,
                          brandLight: brandLight,
                          brand: brand,
                          belowMinimum: widget.belowMinimum,
                        ),
                        const SizedBox(height: 12),
                        // Payment method card
                        _PaymentMethodCard(brandColor: brand),
                        const SizedBox(height: 12),
                        // Phone field
                        _PhoneField(
                          controller: _phoneCtrl,
                          errorMsg: _payState == _PayState.error
                              ? _errorMsg
                              : null,
                          fieldError: _payState == _PayState.idle
                              ? _errorMsg
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      // ── Sticky bottom bar ───────────────────────────────────────────────
      bottomNavigationBar: _payState == _PayState.success
          ? null
          : _BottomBar(
              brand: brand,
              grandTotal: widget.grandTotal,
              isLoading: _payState == _PayState.loading,
              onTap: _placeOrder,
            ),
    );
  }
}

// ─── Success body ─────────────────────────────────────────────────────────────
class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.retailer, required this.amount});

  final RetailerInfo retailer;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'STK Push Sent!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryTeal),
            ),
            const SizedBox(height: 12),
            Text(
              'Check your phone for the M-Pesa prompt\nand enter your PIN to pay KES ${amount.toStringAsFixed(0)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              retailer.name,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: retailer.brandColor),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Pop back to basket compare screen (pop twice to also close the handoff sheet)
                  int popCount = 0;
                  Navigator.popUntil(context, (_) => popCount++ >= 2);
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fulfilment tabs ──────────────────────────────────────────────────────────
class _FulfilmentTabs extends StatelessWidget {
  const _FulfilmentTabs({
    required this.mode,
    required this.brandColor,
    required this.onChanged,
  });

  final _FulfilmentMode mode;
  final Color brandColor;
  final ValueChanged<_FulfilmentMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _Tab(
            label: 'Delivery',
            icon: Icons.local_shipping_outlined,
            active: mode == _FulfilmentMode.delivery,
            brandColor: brandColor,
            onTap: () => onChanged(_FulfilmentMode.delivery),
          ),
          _Tab(
            label: 'Pick At Store',
            icon: Icons.storefront_outlined,
            active: mode == _FulfilmentMode.pickAtStore,
            brandColor: brandColor,
            onTap: () => onChanged(_FulfilmentMode.pickAtStore),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.brandColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color brandColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: active ? brandColor : AppColors.textHint),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? brandColor : AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              color: active ? brandColor : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delivery address card ────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.primaryTeal),
              SizedBox(width: 6),
              Text(
                'Deliver to',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Enter delivery address, e.g. Westlands, Nairobi',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textHint),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Pick-up info card ────────────────────────────────────────────────────────
class _PickUpCard extends StatelessWidget {
  const _PickUpCard({required this.retailerName});

  final String retailerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$retailerName — Nearest Branch',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Walk in and present your order reference',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order summary card ───────────────────────────────────────────────────────
class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.retailer,
    required this.subtotal,
    required this.serviceFee,
    required this.grandTotal,
    required this.itemCount,
    required this.isDelivery,
    required this.brandLight,
    required this.brand,
    required this.belowMinimum,
  });

  final RetailerInfo retailer;
  final double subtotal;
  final double serviceFee;
  final double grandTotal;
  final int itemCount;
  final bool isDelivery;
  final Color brandLight;
  final Color brand;
  final bool belowMinimum;

  @override
  Widget build(BuildContext context) {
    const deliveryFee = 150.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: brandLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: brand),
                const SizedBox(width: 8),
                Text(
                  'Order Summary · $itemCount item${itemCount == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: brand),
                ),
              ],
            ),
          ),
          // Rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Subtotal ($itemCount items)',
                    value: 'KES ${subtotal.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                _SummaryRow(
                    label: 'Service fee (1%)',
                    value: 'KES ${serviceFee.toStringAsFixed(0)}'),
                if (isDelivery) ...[
                  const SizedBox(height: 8),
                  _SummaryRow(
                      label: 'Delivery',
                      value: 'KES ${deliveryFee.toStringAsFixed(0)}+'),
                ],
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total (tax incl.)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      'KES ${grandTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: brand),
                    ),
                  ],
                ),
                if (belowMinimum) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warningAmber.withAlpha(80)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.warningAmber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Below minimum order — you may still proceed.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warningAmber),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Payment method card ──────────────────────────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({required this.brandColor});

  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Icon(Icons.payment_rounded,
                    size: 16, color: AppColors.primaryTeal),
                SizedBox(width: 8),
                Text(
                  'Payment Method',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          // M-Pesa option (pre-selected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.radio_button_checked_rounded,
                    size: 20, color: AppColors.mpesaGreen),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'M-Pesa',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mpesaGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Popular',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mpesaGreen),
                  ),
                ),
              ],
            ),
          ),
          // Debit/Credit card (disabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.radio_button_unchecked_rounded,
                    size: 20, color: AppColors.textHint),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Debit / Credit Card',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textHint),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Coming soon',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Phone field ──────────────────────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    this.errorMsg,
    this.fieldError,
  });

  final TextEditingController controller;
  final String? errorMsg; // inline error below the field (from pay state)
  final String? fieldError; // field-level validation error

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_rounded,
                  size: 16, color: AppColors.mpesaGreen),
              SizedBox(width: 6),
              Text(
                'M-Pesa Phone Number',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '07XXXXXXXX or 254XXXXXXXXX',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textHint),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('🇰🇪',
                    style: TextStyle(fontSize: 18)),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              errorText: fieldError,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMsg!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.accentOrange),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'You will receive an M-Pesa STK push to enter your PIN.',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky bottom bar ────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.brand,
    required this.grandTotal,
    required this.isLoading,
    required this.onTap,
  });

  final Color brand;
  final double grandTotal;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            disabledBackgroundColor: brand.withAlpha(160),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading ? null : onTap,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  'Place Order · KES ${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2),
                ),
        ),
      ),
    );
  }
}
