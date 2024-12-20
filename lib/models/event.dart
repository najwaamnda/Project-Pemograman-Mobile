class Event {
  int? id;
  String title;
  String time;
  String location;
  String description;
  String category;
  String date;

  Event(this.title, this.time, this.location, this.description, this.category,
      {this.id, required this.date,});

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      map['title'],
      map['time'],
      map['location'],
      map['description'],
      map['category'],
      id: map['id'], 
      date: map['date'],
    );
  }

  // String get date => null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'location': location,
      'description': description,
      'category': category,
      'date': date,
    };
  }

}
