import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tubes_app/notification.dart';
import 'models/todo_task.dart';
import 'database_helper.dart';

class ToDoListPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  const ToDoListPage({super.key, required this.notificationsPlugin});

  @override
  State<ToDoListPage> createState() => _ToDoListPageState();
}

class _ToDoListPageState extends State<ToDoListPage> {
  final List<ToDoTask> _tasks = [];
  String _sortOrder = 'Earliest'; // Stores the sort order

  void _loadTasksFromDB() async {
    final tasks = await DatabaseHelper.instance.fetchTasks();
    setState(() {
      _tasks.clear();
      _tasks.addAll(tasks);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTasksFromDB();
  }

  // Function to calculate the percentage of completed tasks
  double _calculateProgress(List<ToDoTask> tasks) {
    if (tasks.isEmpty) return 0;
    final completed = tasks.where((task) => task.isCompleted).length;
    return completed / tasks.length;
  }

  // Function to toggle the task completion status (completed/incomplete)
  Future<void> _toggleTaskCompletion(int index) async {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });

    await DatabaseHelper.instance.updateTaskCompletion(
      _tasks[index].id!,
      _tasks[index].isCompleted,
    );

    // Tunjuin dialog success
    if (_tasks[index].isCompleted) {
      showDialog(
        context: context,
        builder: (context) {
          // dialog
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pop(context);
          });
          return AlertDialog(
            title: const Text('Task Completed!'),
            content: Text(
              'Congrats for completing the task: "${_tasks[index].title}"',
              style: const TextStyle(fontSize: 16),
            ),
          );
        },
      );
    }
  }

  // Function to delete a task after confirmation

  void _confirmDeleteTask(int index) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_tasks.isEmpty || index < 0 || index >= _tasks.length) {
                print('No valid task found for deletion');
                Navigator.pop(context);
                return;
              }

              // Ambil task yang akan dihapus berdasarkan index
              final taskToDelete = _tasks[index];

              try {
                // Hapus task dari database
                await DatabaseHelper.instance.deleteTask(taskToDelete.id!);

                // Hapus task dari list _tasks di UI
                setState(() {
                  _tasks.removeAt(index);
                });

                Navigator.pop(context); // Close dialog after delete

                // Tampilkan dialog success setelah delete
                showDialog(
                  context: context,
                  builder: (context) {
                    Future.delayed(const Duration(seconds: 2), () {
                      Navigator.pop(context); // Close success dialog after 2 seconds
                    });
                    return AlertDialog(
                      title: const Text('Task Successfully Deleted'),
                      content: Text(
                        'The task "${taskToDelete.title}" has been deleted.',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                );
              } catch (e) {
                // Tangani error jika ada masalah dengan penghapusan
                print('Error deleting task: $e');
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
}

  void _sortTasksByDeadline() {
    setState(() {
      if (_sortOrder == 'Latest') {
        _tasks.sort((a, b) => b.deadline.compareTo(a.deadline));
      } else if (_sortOrder == 'Earliest') {
        _tasks.sort((a, b) => a.deadline.compareTo(b.deadline));
      }
    });
  }

  // Function to show add task dialog
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDeadline;
    bool remindMe = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.onBackground),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Deadline: '),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                selectedDeadline = pickedDate;
                              });
                            }
                          },
                          child: Text(
                            selectedDeadline == null
                                ? 'Select Date'
                                : '${selectedDeadline!.day}/${selectedDeadline!.month}/${selectedDeadline!.year}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remind me 1 day before'),
                        Switch(
                          value: remindMe,
                          onChanged: (value) {
                            setDialogState(() {
                              remindMe = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        selectedDeadline == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All fields must be filled!'),
                        ),
                      );
                      return;
                    }

                    final newTask = ToDoTask(
                      title: titleController.text,
                      description: descriptionController.text,
                      deadline: selectedDeadline!,
                      remindMe: remindMe,
                    );

                    if (remindMe) {
                      scheduleToDoListNotification(
                        titleController.text,
                        selectedDeadline!,
                      );
                    }

                    final taskId = await DatabaseHelper.instance
                        .insertTask(newTask); // Save to DB
                    newTask.id = taskId;
                    
                    setState(() {
                      _tasks.add(newTask);
                      _sortTasksByDeadline(); // Sort after adding task
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress(_tasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _sortOrder,
              onChanged: (String? newValue) {
                setState(() {
                  _sortOrder = newValue!;
                  _sortTasksByDeadline();
                });
              },
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white // Text color for dark mode
                    : Colors.black, // Text color for light mode
                fontSize: 16,
              ),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800] // Dropdown background for dark mode
                  : Colors.white, // Dropdown background for light mode
              items: <String>['Earliest', 'Latest']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Displaying progress bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Text(
                    'Task Progress: ${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]
                                : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Task list
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(child: Text('No tasks available.'))
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: task.isCompleted,
                              onChanged: (bool? value) {
                                _toggleTaskCompletion(index);
                              },
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                                'Deadline: ${DateFormat('dd/MM/yyyy').format(task.deadline)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _confirmDeleteTask(index);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
