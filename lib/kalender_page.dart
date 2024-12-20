import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'notification.dart';
import 'all_events_page.dart';
import 'todo_list.dart';
import 'models/event.dart';
import 'database_helper.dart';

class KalenderPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const KalenderPage(
      {super.key,
      required this.onToggleTheme,
      required this.notificationsPlugin});

  @override
  State<KalenderPage> createState() => _KalenderPageState();
}

class _KalenderPageState extends State<KalenderPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Event>> events = {};
  final dbHelper = DatabaseHelper.instance;

  final List<String> categories = [
    "Meeting",
    "Birthday",
    "Important",
    "Others"
  ];

  final Map<String, Color> categoryColors = {
    "Meeting": Colors.blue,
    "Birthday": Colors.purple,
    "Important": Colors.red,
    "Others": Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      // Query semua data dari database
      final data = await dbHelper.queryAll('events');

      // Debugging untuk memastikan data database sudah benar
      print("Database events: $data");

      // Perbarui state
      setState(() {
        events.clear(); // Kosongkan sebelum memperbarui
        for (var map in data) {
          final event = Event.fromMap(map);
          final date = DateTime.parse(map['date']);

          // Tambahkan event ke tanggal yang sesuai
          if (!events.containsKey(date)) {
            events[date] = [];
          }
          final existingIndex =
              events[date]?.indexWhere((e) => e.id == event.id) ?? -1;
          if (existingIndex != -1) {
            events[date]![existingIndex] = event;
          } else {
            events[date]!.add(event);
          }
        }
      });
      // Debugging untuk memastikan map 'events' diperbarui
      print("Events map after load: $events");
    } catch (e) {
      print("Error loading events: $e");
      _showAlert("Failed to load events. Please try again.");
    }
  }

  Future<Event?> _showEventDialog(
      {Event? existingEvent, DateTime? date}) async {
    final titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final locationController =
        TextEditingController(text: existingEvent?.location ?? '');
    final descriptionController =
        TextEditingController(text: existingEvent?.description ?? '');
    String selectedTime = existingEvent?.time ?? '';
    String selectedCategory = existingEvent?.category ?? categories.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(existingEvent == null ? "Add New Event" : "Edit Event"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: "Event Title"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: "Location"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Time: "),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final time = await _pickTime(context);
                            if (time != null) {
                              setState(() {
                                selectedTime = time;
                              });
                            }
                          },
                          child: Text(selectedTime.isEmpty
                              ? "Select Time"
                              : selectedTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                      decoration: const InputDecoration(labelText: "Category"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        selectedTime.isEmpty ||
                        !selectedTime.contains(":") ||
                        locationController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      _showAlert("All fields must be filled!");
                      return;
                    }

                    final newEvent = Event(
                      titleController.text,
                      selectedTime,
                      locationController.text,
                      descriptionController.text,
                      selectedCategory,
                      id: existingEvent?.id,
                      date: existingEvent?.date ??
                          DateTime.now().toIso8601String(),
                    );
                    final eventDate = date ?? _selectedDay!;

                    Navigator.pop(context, true);
                    _saveEvent(newEvent, eventDate);
                    // await _loadEvents();

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    try {
                    // Cek apakah waktu event kurang dari 24 jam
                    final now = DateTime.now();
                    final selectedDate = date ?? _selectedDay!;
                    final timeParts = selectedTime.split(":");
                    final eventDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      int.parse(timeParts[0]), // Jam
                      int.parse(timeParts[1]), // Menit
                    );
                    final difference = eventDateTime.difference(now).inHours;

                    if (difference < 24) {
                      // Tampilkan alert jika waktu kurang dari 24 jam
                      _showAlert("Tidak bisa menjadwalkan event");
                    } else {
                      // Jadwalkan notifikasi jika waktu lebih dari 24 jam
                      await scheduleReminderNotification(
                          titleController.text, eventDateTime);
                    }

                    // Menyimpan event ke dalam daftar
                    setState(() {
                      if (existingEvent != null) {
                        // Ganti event lama dengan yang baru
                        final date = DateTime.parse(existingEvent.date);
                        final index = events[date]
                            ?.indexWhere((e) => e.id == existingEvent.id);
                        if (index != null && index != -1) {
                          events[date]![index] = newEvent;
                        }
                      } else {
                        events[eventDate] = [
                          ...(events[eventDate] ?? []),
                          newEvent
                        ];
                      }
                    });

                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    // Tangani error
                    print("Error saving event: $e");
                    _showAlert("Gagal menyimpan event. Coba lagi!");
                  } finally {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  }
                },

                  //   try {
                  //     // Proses penyimpanan event
                  //     setState(() {
                  //       if (existingEvent != null) {
                  //         // Ganti event lama dengan yang baru
                  //         final date = DateTime.parse(existingEvent.date);
                  //         final index = events[date]
                  //             ?.indexWhere((e) => e.id == existingEvent.id);
                  //         if (index != null && index != -1) {
                  //           events[date]![index] = newEvent;
                  //         }
                  //       } else {
                  //         // final eventDate = date ?? _selectedDay!;
                  //         events[eventDate] = [
                  //           ...(events[eventDate] ?? []),
                  //           newEvent
                  //         ];
                  //       }
                  //     });

                  //     // Jadwalkan notifikasi sehari sebelum event
                  //     if (selectedTime.isEmpty || !selectedTime.contains(":")) {
                  //       throw FormatException(
                  //           "Invalid time format: $selectedTime");
                  //     }

                  //     final selectedDate = date ?? _selectedDay!;
                  //     final timeParts = selectedTime.split(":");
                  //     final eventDateTime = DateTime(
                  //       selectedDate.year,
                  //       selectedDate.month,
                  //       selectedDate.day,
                  //       int.parse(timeParts[0]), // Jam
                  //       int.parse(timeParts[1]), // Menit
                  //     );

                  //     await scheduleReminderNotification(
                  //         titleController.text, eventDateTime);

                  //     if (Navigator.canPop(context)) {
                  //       Navigator.pop(context);
                  //     }
                  //   } catch (e) {
                  //     // Tangani error
                  //     print("Error saving event: $e");
                  //     _showAlert("Gagal menyimpan event. Coba lagi!");
                  //   } finally {
                  //     if (Navigator.canPop(context)) {
                  //       Navigator.pop(context);
                  //     }
                  //   }
                  // },
                  child: Text(existingEvent == null ? "Save" : "Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveEvent(Event eventObj, DateTime eventDate) async {
    // Susun data sebagai Map<String, dynamic>
    Map<String, dynamic> event = {
      'title': eventObj.title,
      'time': eventObj.time,
      'location': eventObj.location,
      'description': eventObj.description,
      'category': eventObj.category,
      'date': eventDate.toIso8601String(), // Konversi DateTime ke String
    };

    // Debug untuk memastikan isi event
    print("Saving event: $event");

    // Simpan ke database melalui DatabaseHelper
    try {
      if (eventObj.id != null) {
        await dbHelper.update('events', event, eventObj.id!);
        print("Event successfully saved to database: $event");
      } else {
        await dbHelper.insert('events', event);
        print("Event successfully saved to database: $event");
      }
      await _loadEvents();

      if (mounted) {
        _showAutoDismissAlert(eventObj.id != null
            ? "Event successfully updated!"
            : "Event successfully added!");
      }
    } catch (e) {
      print("Error saving event: $e");
      if (mounted) {
        _showAlert("Failed to save event. Please try again.");
      }
    }
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Confirmation"),
          content: const Text("Are you sure you want to delete this event?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Kembalikan false jika batal
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context, true); // Kembalikan true jika ingin hapus
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Hapus dari database
        if (event.id != null) {
          final deletedCount = await dbHelper.delete('events', event.id!);
          print(
              "Deleted rows: $deletedCount"); // Debugging untuk melihat jumlah data yang dihapus
        }

        // Perbarui state untuk menghapus event dari memori
        setState(() {
          events.updateAll((date, eventList) {
            eventList
                .removeWhere((e) => e.id == event.id); // Hapus berdasarkan ID
            return eventList;
          });
        });

        // Sinkronkan ulang data dari database
        await _loadEvents();

        // Tampilkan pesan sukses
        _showAutoDismissAlert("Event successfully deleted!");
      } catch (e) {
        print("Error deleting event: $e");
        _showAlert("Failed to delete event. Please try again.");
      }
    }
  }

  Future<String?> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      // Format ke 24 jam
      return "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    }
    return null;
  }

  void _showAutoDismissAlert(String message) {
    print("Alert is being shown: $message");
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Success!"),
            content: Text(message),
          );
        },
      );
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Peringatan"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  List<Event> _getEventsForDay(DateTime day) {
    return events[day] ?? [];
  }

  List<Event> _getAllEvents() {
    return events.values.expand((eventList) => eventList).toList();
  }

  void _navigateToAllEventsPage(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllEventsPage(
          events: _getAllEvents(),
          onDelete: _deleteEvent,
          onUpdate: ({Event? existingEvent, DateTime? date}) async {
            final updatedEvent = await _showEventDialog(
                existingEvent: existingEvent, date: date);
            if (updatedEvent != null) {
              await _loadEvents();
              return updatedEvent;
            }
            return null;
          },
          categoryColors: categoryColors,
        ),
      ),
    );

    if (result == true) {
      await _loadEvents();
    }
  }

  void _navigateToToDoListPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ToDoListPage(notificationsPlugin: widget.notificationsPlugin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.event_note),
            onPressed: () => _navigateToAllEventsPage(context),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _navigateToToDoListPage(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) => _getEventsForDay(day),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children:
                  _getEventsForDay(_selectedDay ?? _focusedDay).map((event) {
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(event.title),
                    subtitle: Text('${event.time} - ${event.location}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteEvent(event);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(date: _selectedDay),
        backgroundColor: const Color.fromARGB(
            255, 180, 175, 250), // Ganti dengan warna yang diinginkan
        child: const Icon(Icons.add),
      ),
    );
  }
}
