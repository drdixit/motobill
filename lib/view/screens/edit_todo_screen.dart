import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/todo.dart';
import '../../view_model/todo_viewmodel.dart';

class EditTodoScreen extends ConsumerStatefulWidget {
  final Todo todo;

  const EditTodoScreen({super.key, required this.todo});

  @override
  ConsumerState<EditTodoScreen> createState() => _EditTodoScreenState();
}

class _EditTodoScreenState extends ConsumerState<EditTodoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.todo.name);
    _descriptionController = TextEditingController(
      text: widget.todo.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Todo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateTodo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Update Todo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTodo() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      final updatedTodo = widget.todo.copyWith(
        name: name,
        description: description,
      );

      await ref.read(todoViewModelProvider.notifier).updateTodo(updatedTodo);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
