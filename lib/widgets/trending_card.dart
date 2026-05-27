import 'package:flutter/material.dart';

class TrendingCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final bool isLarge;

  const TrendingCard({
    super.key,
    required this.rank,
    required this.data,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final double width = isLarge ? 210.0 : 150.0;
    final double imgHeight = isLarge ? 130.0 : 100.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isLarge
                  ? const Color(0x22000000)
                  : const Color(0x0F000000),
              blurRadius: isLarge ? 16 : 8,
              offset: isLarge ? const Offset(0, 4) : Offset.zero,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: data['imgUrl'] != null &&
                          data['imgUrl'].toString().isNotEmpty
                      ? Image.network(
                          data['imgUrl'],
                          height: imgHeight,
                          width: width,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(width, imgHeight),
                        )
                      : _imgPlaceholder(width, imgHeight),
                ),
                if (rank != -1)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? Colors.orange
                            : rank <= 3
                                ? Colors.deepOrange
                                : Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rank == 1 ? '🥇 1위' : '# $rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isLarge ? 14 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        data['time'] ?? '-',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.trending_up,
                          size: 11, color: Colors.orange),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          data['level'] ?? '-',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder(double width, double height) => Container(
        height: height,
        width: width,
        color: Colors.grey[100],
        child: const Icon(Icons.restaurant, color: Colors.orange, size: 36),
      );
}
