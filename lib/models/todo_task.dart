class ToDoTask {
  int? id; // Tambahkan ID untuk identifikasi unik
  String title;
  String description;
  DateTime deadline;
  bool isCompleted;
  bool remindMe;

  ToDoTask({
    this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.isCompleted = false,
    this.remindMe = false,
  });

  // Convert object to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  // Create object from map
  factory ToDoTask.fromMap(Map<String, dynamic> map) {
    return ToDoTask(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      deadline: DateTime.parse(map['deadline']),
      isCompleted: map['isCompleted'] == 1,
    );
  }
}
