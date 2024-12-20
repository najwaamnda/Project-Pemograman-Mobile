import 'package:flutter/material.dart';
import 'models/event.dart';

class AllEventsPage extends StatefulWidget {
  final List<Event> events;
  final Function(Event) onDelete;
  final Future<Event?> Function({Event? existingEvent, DateTime? date})
      onUpdate;
  final Map<String, Color> categoryColors;

  const AllEventsPage({
    required this.events,
    required this.onDelete,
    required this.onUpdate,
    required this.categoryColors,
    super.key,
  });

  @override
  State<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends State<AllEventsPage> {
  String _searchQuery = "";
  String _selectedCategory = "All";

  List<Event> get _filteredEvents {
    return widget.events.where((event) {
      final matchesSearch = event.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          event.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == "All" || event.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await widget.onDelete(event);
      setState(() {
        widget.events.removeWhere((e) => e.id == event.id);
      });
    }
  }

  Future<void> _editEvent(Event event) async {
    final updatedEvent = await widget.onUpdate(existingEvent: event);
    if (updatedEvent != null) {
      setState(() {
        final index =
            widget.events.indexWhere((existing) => existing.id == event.id);
        if (index != -1) {
          widget.events[index] = updatedEvent;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _filteredEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Events"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Search Event",
                    hintText: "Enter keywords...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: ["All", ...widget.categoryColors.keys]
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Category Filter",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: filteredEvents.isEmpty
          ? const Center(child: Text("No events match."))
          : ListView.builder(
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                final categoryColor =
                    widget.categoryColors[event.category] ?? Colors.grey;

                return Card(
                  elevation: 3,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 80,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          title: Text(
                            event.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Time: ${event.time}"),
                              Text("Location: ${event.location}"),
                              Text(
                                "Category: ${event.category}",
                                style: TextStyle(color: categoryColor),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blueAccent),
                                onPressed: () => _editEvent(event),
                                tooltip: "Update Event",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () => _deleteEvent(event),
                                tooltip: "Delete Event",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
