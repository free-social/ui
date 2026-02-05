import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/expense_provider.dart';
import '../screens/transaction_form_screen.dart'; 

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      // 1. Swipe-to-Delete
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(context),
      onDismissed: (direction) {
        _deleteTransaction(context);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              transaction.category.isNotEmpty ? transaction.category[0].toUpperCase() : "?",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          title: Text(
            transaction.description,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(_capitalize(transaction.category)),
          
          // 2. Buttons Row (Price | Edit | Delete)
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "\$${transaction.amount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                padding: EdgeInsets.zero, 
                constraints: const BoxConstraints(),
                onPressed: () => _openEditScreen(context), // ✅ Opens Full Screen Form
              ),
              const SizedBox(width: 12),
              
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  bool confirm = await _showDeleteConfirmation(context) ?? false;
                  if (confirm && context.mounted) {
                    _deleteTransaction(context);
                  }
                },
              ),
            ],
          ),
          onTap: () => _openEditScreen(context), // ✅ Tap tile to edit too
        ),
      ),
    );
  }

  // --- Helper to Open Edit Screen ---
  void _openEditScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(transaction: transaction),
      ),
    );
  }

  // --- Logic for Deleting ---
  void _deleteTransaction(BuildContext context) {
    Provider.of<ExpenseProvider>(context, listen: false).deleteTransaction(transaction.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${transaction.description} deleted")),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Are you sure you want to remove this transaction?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }

  // Simple capitalization helper
  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}