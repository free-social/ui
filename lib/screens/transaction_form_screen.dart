import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import '../utils/snackbar_helper.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final Color kPrimaryColor = const Color(0xFF00BFA5);

  // ✅ UPDATED TO MATCH HOME_VIEW ICONS & COLORS
  final List<Map<String, dynamic>> _categories = [
    {'name': 'food', 'icon': Icons.local_cafe, 'color': Colors.teal},
    {'name': 'travel', 'icon': Icons.directions_car, 'color': Colors.orange},
    {
      'name': 'bills',
      'icon': Icons.receipt_long,
      'color': const Color(0xFFFF5252),
    },
    {'name': 'shopping', 'icon': Icons.shopping_bag, 'color': Colors.purple},
    {
      'name': 'rent',
      'icon': Icons.home,
      'color': Colors.indigo,
    }, // Added Rent case
    {'name': 'other', 'icon': Icons.category, 'color': Colors.blueGrey},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _noteController.text = widget.transaction!.description;
      _selectedCategory = widget.transaction!.category.toLowerCase();
      _selectedDate = widget.transaction!.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: kPrimaryColor)),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (_selectedCategory == null) {
      showErrorSnackBar(context, 'Please select a category');
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      showErrorSnackBar(context, 'Please enter a valid amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final String categoryKey = _selectedCategory!.toLowerCase();

      if (widget.transaction == null) {
        await provider.addTransaction(
          amount,
          categoryKey,
          _noteController.text,
          _selectedDate,
        );
      } else {
        await provider.updateTransaction(widget.transaction!.id, {
          "amount": amount,
          "category": categoryKey,
          "description": _noteController.text,
          "date": _selectedDate.toIso8601String(),
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Full Error: $e");
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    // ✅ 1. SETUP DYNAMIC COLORS (Strictly typed)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color labelColor = isDark ? Colors.grey[400]! : Colors.grey;
    final Color inputFillColor = isDark
        ? Colors.grey[800]!
        : const Color(0xFFF9FAFB);
    final Color iconColor = isDark ? Colors.white : Colors.black;

    final bool isEditing = widget.transaction != null;

    return Scaffold(
      backgroundColor: bgColor, // ✅ Dynamic
      appBar: AppBar(
        backgroundColor: bgColor, // ✅ Dynamic
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: iconColor), // ✅ Dynamic
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? "Edit Expense" : "Add Expense",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ), // ✅ Dynamic
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _buildAmountInput(labelColor), // ✅ No '!' needed
            const SizedBox(height: 30),

            _buildDatePicker(
              inputFillColor,
              textColor,
              iconColor,
            ), // ✅ No '!' needed
            const SizedBox(height: 30),

            _buildCategorySelector(labelColor, inputFillColor, textColor),
            const SizedBox(height: 30),

            _buildNoteInput(labelColor, inputFillColor, iconColor),
            const SizedBox(height: 40),

            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildAmountInput(Color labelColor) {
    return Column(
      children: [
        Text(
          "AMOUNT",
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ), // ✅ Dynamic
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: widget.transaction == null,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: "0.00",
            prefixText: "\$ ",
            prefixStyle: TextStyle(
              fontSize: 48,
              color: kPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(Color fillColor, Color textColor, Color iconColor) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor, // ✅ Dynamic
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: iconColor.withOpacity(0.7),
            ), // ✅ Dynamic
            const SizedBox(width: 10),
            Text(
              DateFormat('MMMM d, yyyy • h:mm a').format(_selectedDate),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ), // ✅ Dynamic
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.arrow_drop_down,
              color: iconColor.withOpacity(0.5),
            ), // ✅ Dynamic
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(
    Color labelColor,
    Color inactiveBg,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CATEGORY",
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ), // ✅ Dynamic
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              bool isSelected = _selectedCategory == cat['name'];
              return GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _selectedCategory = cat['name']);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kPrimaryColor
                              : inactiveBg, // ✅ Dynamic Inactive BG
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cat['icon'],
                          color: isSelected ? Colors.white : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['name'].toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? kPrimaryColor : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteInput(Color labelColor, Color fillColor, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "NOTE",
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ), // ✅ Dynamic
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          style: TextStyle(color: iconColor), // ✅ Dynamic Input Text
          decoration: InputDecoration(
            hintText: "Enter note...",
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(
              Icons.notes,
              color: iconColor.withOpacity(0.6),
            ), // ✅ Dynamic
            filled: true,
            fillColor: fillColor, // ✅ Dynamic
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                widget.transaction == null ? "Save Expense" : "Update Expense",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
