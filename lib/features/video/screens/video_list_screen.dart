import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoListScreen extends StatelessWidget {
  final storage = FirebaseStorage.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const Center(child: Text('Not logged in'));

    return Scaffold(
      appBar: AppBar(title: const Text('My Videos')),
      body: FutureBuilder<ListResult>(
        future: storage.ref('videos/$userId').listAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!.items;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                trailing: Text('${(item.fullPath)}'),
                onTap: () async {
                  final url = await item.getDownloadURL();
                  print('Video URL: $url');
                },
              );
            },
          );
        },
      ),
    );
  }
} 